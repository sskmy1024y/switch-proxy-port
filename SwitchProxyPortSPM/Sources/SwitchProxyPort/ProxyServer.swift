import Foundation
import Network
import SwiftUI

class ProxyServer: ObservableObject {
    private var listener: NWListener?
    private var connections: Set<ProxyConnection> = []
    
    @Published var isRunning = false
    
    private var listenPort: Int = 8080
    private var targetPort: Int = 3000
    private let queue = DispatchQueue(label: "proxy-server", qos: .utility)
    
    weak var delegate: ProxyServerDelegate?
    
    func start(listenPort: Int, targetPort: Int) {
        guard !isRunning else { 
            print("⚠️ ProxyServer: Already running")
            return 
        }
        
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
            
        } catch {
            delegate?.proxyServerDidFailToStart(error)
        }
    }
    
    func stop() {
        guard isRunning else { return }
        
        listener?.cancel()
        listener = nil
        
        for connection in connections {
            connection.cancel()
        }
        connections.removeAll()
        
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
        connections.insert(proxyConnection)
        proxyConnection.start()
        print("📊 ProxyServer: Active connections: \(connections.count)")
    }
    
    private func handleListenerStateUpdate(_ state: NWListener.State) {
        switch state {
        case .ready:
            print("✅ ProxyServer: Listener ready on port \(listenPort)")
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = true
            }
            delegate?.proxyServerDidStart(on: listenPort)
        case .failed(let error):
            print("❌ ProxyServer: Listener failed: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = false
            }
            delegate?.proxyServerDidFailToStart(error)
        case .cancelled:
            print("🛑 ProxyServer: Listener cancelled")
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
        connections.remove(connection)
        print("🔌 ProxyServer: Connection closed. Active connections: \(connections.count)")
    }
    
    func proxyConnectionDidFail(_ connection: ProxyConnection, error: Error) {
        connections.remove(connection)
        print("❌ ProxyServer: Connection failed: \(error). Active connections: \(connections.count)")
        delegate?.proxyServerDidEncounterError(error)
    }
}

protocol ProxyServerDelegate: AnyObject {
    func proxyServerDidStart(on port: Int)
    func proxyServerDidStop()
    func proxyServerDidFailToStart(_ error: Error)
    func proxyServerDidSwitchTarget(to port: Int)
    func proxyServerDidEncounterError(_ error: Error)
}