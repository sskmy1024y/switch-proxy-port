import Foundation
import Network

class ProxyConnection: Hashable {
    private let clientConnection: NWConnection
    private var serverConnection: NWConnection?
    private let targetHost: String
    private let targetPort: Int
    private let queue: DispatchQueue
    private let id = UUID()

    // State management to prevent duplicate delegate calls
    private var isCancelled = false
    private var hasNotifiedDelegate = false
    private let stateLock = NSLock()

    weak var delegate: ProxyConnectionDelegate?

    init(clientConnection: NWConnection, targetHost: String, targetPort: Int, queue: DispatchQueue) {
        self.clientConnection = clientConnection
        self.targetHost = targetHost
        self.targetPort = targetPort
        self.queue = queue
    }
    
    func start() {
        print("📡 ProxyConnection: Starting connection from client to \(targetHost):\(targetPort)")
        
        // Start client connection first
        clientConnection.stateUpdateHandler = { [weak self] state in
            self?.handleClientConnectionState(state)
        }
        clientConnection.start(queue: queue)
        
        // Connect to target server
        connectToTarget()
    }
    
    func cancel() {
        stateLock.lock()
        guard !isCancelled else {
            stateLock.unlock()
            return
        }
        isCancelled = true
        stateLock.unlock()

        clientConnection.cancel()
        serverConnection?.cancel()
    }

    /// Safely notify delegate only once
    private func notifyClose() {
        stateLock.lock()
        guard !hasNotifiedDelegate else {
            stateLock.unlock()
            return
        }
        hasNotifiedDelegate = true
        stateLock.unlock()

        delegate?.proxyConnectionDidClose(self)
    }

    /// Safely notify delegate of failure only once
    private func notifyFailure(_ error: Error) {
        stateLock.lock()
        guard !hasNotifiedDelegate else {
            stateLock.unlock()
            return
        }
        hasNotifiedDelegate = true
        stateLock.unlock()

        delegate?.proxyConnectionDidFail(self, error: error)
    }
    
    private func connectToTarget() {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(targetHost),
            port: NWEndpoint.Port(integerLiteral: UInt16(targetPort))
        )
        
        let tcpOptions = NWProtocolTCP.Options()
        let parameters = NWParameters(tls: nil, tcp: tcpOptions)
        
        serverConnection = NWConnection(to: endpoint, using: parameters)
        
        serverConnection?.stateUpdateHandler = { [weak self] state in
            self?.handleServerConnectionState(state)
        }
        
        serverConnection?.start(queue: queue)
    }
    
    private func handleClientConnectionState(_ state: NWConnection.State) {
        // Skip if already cancelled
        stateLock.lock()
        let cancelled = isCancelled
        stateLock.unlock()
        if cancelled && state != .cancelled { return }

        switch state {
        case .ready:
            print("🔗 ProxyConnection: Client connection ready")
            startReceivingFromClient()
        case .failed(let error):
            print("❌ ProxyConnection: Client connection failed: \(error)")
            cancel()
            notifyFailure(error)
        case .cancelled:
            print("🚫 ProxyConnection: Client connection cancelled")
            notifyClose()
        default:
            break
        }
    }

    private func handleServerConnectionState(_ state: NWConnection.State) {
        // Skip if already cancelled
        stateLock.lock()
        let cancelled = isCancelled
        stateLock.unlock()
        if cancelled && state != .cancelled { return }

        switch state {
        case .ready:
            print("🎯 ProxyConnection: Server connection ready to \(targetHost):\(targetPort)")
            startReceivingFromServer()
        case .failed(let error):
            print("❌ ProxyConnection: Server connection failed: \(error)")
            cancel()
            notifyFailure(error)
        case .cancelled:
            print("🚫 ProxyConnection: Server connection cancelled")
            notifyClose()
        default:
            break
        }
    }
    
    private func startReceivingFromClient() {
        // Check if already cancelled before receiving
        stateLock.lock()
        let cancelled = isCancelled
        stateLock.unlock()
        if cancelled { return }

        clientConnection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            // Check if cancelled during receive
            self.stateLock.lock()
            let wasCancelled = self.isCancelled
            self.stateLock.unlock()
            if wasCancelled { return }

            if let error = error {
                self.cancel()
                self.notifyFailure(error)
                return
            }

            if let data = data, !data.isEmpty {
                print("⬆️ ProxyConnection: Forwarding \(data.count) bytes from client to server")
                self.serverConnection?.send(content: data, completion: .contentProcessed { sendError in
                    if let sendError = sendError {
                        print("❌ ProxyConnection: Failed to send data to server: \(sendError)")
                        self.cancel()
                        self.notifyFailure(sendError)
                    }
                })
            }

            if isComplete {
                self.cancel()
                self.notifyClose()
            } else {
                self.startReceivingFromClient()
            }
        }
    }

    private func startReceivingFromServer() {
        // Check if already cancelled before receiving
        stateLock.lock()
        let cancelled = isCancelled
        stateLock.unlock()
        if cancelled { return }

        serverConnection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            // Check if cancelled during receive
            self.stateLock.lock()
            let wasCancelled = self.isCancelled
            self.stateLock.unlock()
            if wasCancelled { return }

            if let error = error {
                self.cancel()
                self.notifyFailure(error)
                return
            }

            if let data = data, !data.isEmpty {
                print("⬇️ ProxyConnection: Forwarding \(data.count) bytes from server to client")
                self.clientConnection.send(content: data, completion: .contentProcessed { sendError in
                    if let sendError = sendError {
                        print("❌ ProxyConnection: Failed to send data to client: \(sendError)")
                        self.cancel()
                        self.notifyFailure(sendError)
                    }
                })
            }

            if isComplete {
                self.cancel()
                self.notifyClose()
            } else {
                self.startReceivingFromServer()
            }
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ProxyConnection, rhs: ProxyConnection) -> Bool {
        return lhs.id == rhs.id
    }
}

protocol ProxyConnectionDelegate: AnyObject {
    func proxyConnectionDidClose(_ connection: ProxyConnection)
    func proxyConnectionDidFail(_ connection: ProxyConnection, error: Error)
}

enum ProxyError: Error {
    case connectionClosed
    case invalidData
    case serverUnavailable
}