import Foundation
import Network
import SwiftUI

struct ProxyHealthConfig {
    let healthCheckInterval: TimeInterval
    let maxRetryAttempts: Int
    let maxConnectionFailures: Int
    let healthCheckTimeout: TimeInterval
    
    static let `default` = ProxyHealthConfig(
        healthCheckInterval: 30.0,
        maxRetryAttempts: 3,
        maxConnectionFailures: 5,
        healthCheckTimeout: 5.0
    )
}

class ProxyServer: ObservableObject {
    private var listener: NWListener?
    private var connections: Set<ProxyConnection> = []
    private let connectionsLock = NSLock()

    @Published var isRunning = false

    private var listenPort: Int = 8080
    private(set) var targetPort: Int = 3000
    private let queue = DispatchQueue(label: "proxy-server", qos: .utility)

    weak var delegate: ProxyServerDelegate?

    // Health check properties
    private var healthCheckTimer: Timer?
    private let healthConfig: ProxyHealthConfig
    private var currentRetryAttempt = 0
    private var isHealthy = true
    private var lastHealthCheckTime: Date?

    // Connection monitoring
    private var connectionFailureCount = 0
    private var connectionFailureResetTimer: Timer?
    private let connectionFailureQueue = DispatchQueue(label: "connection-failure-counter")

    // Restart state management
    private var isRestarting = false
    private let restartLock = NSLock()

    // Start/stop state management
    private var isStarting = false
    private let startLock = NSLock()

    init(healthConfig: ProxyHealthConfig = .default) {
        self.healthConfig = healthConfig
    }
    
    func start(listenPort: Int, targetPort: Int) {
        // Prevent concurrent start attempts
        startLock.lock()
        guard !isStarting && !isRunning else {
            startLock.unlock()
            print("⚠️ ProxyServer: Already running or starting")
            return
        }
        isStarting = true
        startLock.unlock()

        print("🚀 ProxyServer: Starting on port \(listenPort) → \(targetPort)")
        self.listenPort = listenPort
        self.targetPort = targetPort

        do {
            let tcpOptions = NWProtocolTCP.Options()
            let parameters = NWParameters(tls: nil, tcp: tcpOptions)
            parameters.allowLocalEndpointReuse = true
            parameters.includePeerToPeer = true

            listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: UInt16(listenPort)))

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }

            listener?.stateUpdateHandler = { [weak self] state in
                self?.handleListenerStateUpdate(state)
            }

            listener?.start(queue: queue)

            // Start health check
            startHealthCheck()

        } catch {
            startLock.lock()
            isStarting = false
            startLock.unlock()

            delegate?.proxyServerDidFailToStart(error)
            // Attempt auto-restart on initial failure
            attemptAutoRestart()
        }
    }
    
    func stop() {
        startLock.lock()
        let wasRunning = isRunning
        isStarting = false
        startLock.unlock()

        guard wasRunning else { return }

        // Stop health check
        stopHealthCheck()

        listener?.cancel()
        listener = nil

        // Thread-safe connection cleanup
        connectionsLock.lock()
        let connectionsToCancel = connections
        connections.removeAll()
        connectionsLock.unlock()

        for connection in connectionsToCancel {
            connection.cancel()
        }

        DispatchQueue.main.async { [weak self] in
            self?.isRunning = false
        }
        delegate?.proxyServerDidStop()
    }
    
    func switchTarget(to port: Int) {
        self.targetPort = port
        delegate?.proxyServerDidSwitchTarget(to: port)
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        print("🔌 ProxyServer: New connection received, forwarding to \(targetPort)")
        let proxyConnection = ProxyConnection(
            clientConnection: connection,
            targetHost: "127.0.0.1",
            targetPort: targetPort,
            queue: queue
        )

        proxyConnection.delegate = self

        // Thread-safe insertion
        connectionsLock.lock()
        connections.insert(proxyConnection)
        let count = connections.count
        connectionsLock.unlock()

        proxyConnection.start()
        print("📊 ProxyServer: Active connections: \(count)")
    }
    
    private func handleListenerStateUpdate(_ state: NWListener.State) {
        switch state {
        case .ready:
            print("✅ ProxyServer: Listener ready on port \(listenPort)")
            let previousAttempts = currentRetryAttempt

            // Clear restart and starting flags
            restartLock.lock()
            isRestarting = false
            restartLock.unlock()

            startLock.lock()
            isStarting = false
            startLock.unlock()

            DispatchQueue.main.async { [weak self] in
                self?.isRunning = true
                self?.isHealthy = true
                self?.currentRetryAttempt = 0
            }
            delegate?.proxyServerDidStart(on: listenPort)

            // Notify about recovery if this was after a restart attempt
            if previousAttempts > 0 {
                delegate?.proxyServerDidRecover(after: previousAttempts)
            }
        case .failed(let error):
            print("❌ ProxyServer: Listener failed: \(error)")

            startLock.lock()
            isStarting = false
            startLock.unlock()

            DispatchQueue.main.async { [weak self] in
                self?.isRunning = false
                self?.isHealthy = false
            }
            delegate?.proxyServerDidFailToStart(error)
            // Attempt auto-restart on listener failure
            attemptAutoRestart()
        case .cancelled:
            print("🛑 ProxyServer: Listener cancelled")

            startLock.lock()
            isStarting = false
            startLock.unlock()

            DispatchQueue.main.async { [weak self] in
                self?.isRunning = false
            }
            delegate?.proxyServerDidStop()
        default:
            break
        }
    }
}

extension ProxyServer: ProxyConnectionDelegate {
    func proxyConnectionDidClose(_ connection: ProxyConnection) {
        // Thread-safe removal
        connectionsLock.lock()
        connections.remove(connection)
        let count = connections.count
        connectionsLock.unlock()

        print("🔌 ProxyServer: Connection closed. Active connections: \(count)")
    }

    func proxyConnectionDidFail(_ connection: ProxyConnection, error: Error) {
        // Thread-safe removal
        connectionsLock.lock()
        connections.remove(connection)
        let count = connections.count
        connectionsLock.unlock()

        print("❌ ProxyServer: Connection failed: \(error). Active connections: \(count)")
        delegate?.proxyServerDidEncounterError(error)

        // Track connection failures
        connectionFailureQueue.async { [weak self] in
            guard let self = self else { return }

            self.connectionFailureCount += 1
            let currentCount = self.connectionFailureCount
            let maxFailures = self.healthConfig.maxConnectionFailures

            if currentCount >= maxFailures {
                print("⚠️ ProxyServer: Too many connection failures (\(currentCount)). Attempting restart...")
                DispatchQueue.main.async {
                    self.isHealthy = false
                    self.attemptAutoRestart()
                }
            }

            // Reset failure count after some time
            DispatchQueue.main.async {
                self.connectionFailureResetTimer?.invalidate()
                self.connectionFailureResetTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { [weak self] _ in
                    self?.connectionFailureQueue.async {
                        self?.connectionFailureCount = 0
                    }
                }
            }
        }
    }
}

// MARK: - Health Check and Auto-Restart

private extension ProxyServer {
    func startHealthCheck() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: healthConfig.healthCheckInterval, repeats: true) { [weak self] _ in
            self?.performHealthCheck()
        }
    }
    
    func stopHealthCheck() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        connectionFailureResetTimer?.invalidate()
        connectionFailureResetTimer = nil
    }
    
    func performHealthCheck() {
        lastHealthCheckTime = Date()
        
        // Check if listener is still active
        guard let listener = listener, listener.state == .ready else {
            print("⚠️ ProxyServer: Health check failed - listener not ready")
            isHealthy = false
            attemptAutoRestart()
            return
        }
        
        // Check target port availability
        checkTargetPortAvailability { [weak self] available in
            if !available {
                print("⚠️ ProxyServer: Target port \(self?.targetPort ?? 0) not available - will attempt auto-restart")
                self?.isHealthy = false
                self?.attemptAutoRestart()
            } else {
                self?.isHealthy = true
            }
        }
    }
    
    func checkTargetPortAvailability(completion: @escaping (Bool) -> Void) {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host("127.0.0.1"),
            port: NWEndpoint.Port(integerLiteral: UInt16(targetPort))
        )

        let connection = NWConnection(to: endpoint, using: .tcp)
        let completionLock = NSLock()
        var isCompleted = false

        connection.stateUpdateHandler = { state in
            completionLock.lock()
            guard !isCompleted else {
                completionLock.unlock()
                return
            }

            switch state {
            case .ready:
                isCompleted = true
                completionLock.unlock()
                connection.cancel()
                completion(true)
            case .failed, .cancelled:
                isCompleted = true
                completionLock.unlock()
                connection.cancel()  // Ensure cleanup on failure
                completion(false)
            default:
                completionLock.unlock()
            }
        }

        connection.start(queue: queue)

        // Timeout after configured time
        DispatchQueue.main.asyncAfter(deadline: .now() + healthConfig.healthCheckTimeout) {
            completionLock.lock()
            guard !isCompleted else {
                completionLock.unlock()
                return
            }
            isCompleted = true
            completionLock.unlock()

            connection.cancel()
            completion(false)
        }
    }
    
    func attemptAutoRestart() {
        // Prevent multiple concurrent restart attempts
        restartLock.lock()
        guard !isRestarting else {
            restartLock.unlock()
            print("⚠️ ProxyServer: Restart already in progress, skipping")
            return
        }

        guard currentRetryAttempt < healthConfig.maxRetryAttempts else {
            restartLock.unlock()
            print("❌ ProxyServer: Max retry attempts reached. Giving up.")
            delegate?.proxyServerDidFailToStart(ProxyError.serverUnavailable)
            return
        }

        isRestarting = true
        currentRetryAttempt += 1
        let attemptNumber = currentRetryAttempt
        let maxAttempts = healthConfig.maxRetryAttempts
        restartLock.unlock()

        let delay = Double(attemptNumber) * 2.0 // Exponential backoff

        print("🔄 ProxyServer: Attempting restart (\(attemptNumber)/\(maxAttempts)) in \(delay) seconds...")

        // Notify delegate about restart attempt
        delegate?.proxyServerWillRestart(attempt: attemptNumber, maxAttempts: maxAttempts)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }

            // Stop current instance
            self.stop()

            // Restart after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.start(listenPort: self.listenPort, targetPort: self.targetPort)
            }
        }
    }
}

protocol ProxyServerDelegate: AnyObject {
    func proxyServerDidStart(on port: Int)
    func proxyServerDidStop()
    func proxyServerDidFailToStart(_ error: Error)
    func proxyServerDidSwitchTarget(to port: Int)
    func proxyServerDidEncounterError(_ error: Error)
    func proxyServerDidRecover(after attempt: Int)
    func proxyServerWillRestart(attempt: Int, maxAttempts: Int)
}