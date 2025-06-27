import Foundation
import Network

class ProxyConnection: Hashable {
    private let clientConnection: NWConnection
    private var serverConnection: NWConnection?
    private let targetHost: String
    private let targetPort: Int
    private let queue: DispatchQueue
    private let id = UUID()
    
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
        clientConnection.cancel()
        serverConnection?.cancel()
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
        switch state {
        case .ready:
            print("🔗 ProxyConnection: Client connection ready")
            startReceivingFromClient()
        case .failed(let error):
            print("❌ ProxyConnection: Client connection failed: \(error)")
            delegate?.proxyConnectionDidFail(self, error: error)
        case .cancelled:
            print("🚫 ProxyConnection: Client connection cancelled")
            delegate?.proxyConnectionDidClose(self)
        default:
            break
        }
    }
    
    private func handleServerConnectionState(_ state: NWConnection.State) {
        switch state {
        case .ready:
            print("🎯 ProxyConnection: Server connection ready to \(targetHost):\(targetPort)")
            startReceivingFromServer()
        case .failed(let error):
            print("❌ ProxyConnection: Server connection failed: \(error)")
            delegate?.proxyConnectionDidFail(self, error: error)
        case .cancelled:
            print("🚫 ProxyConnection: Server connection cancelled")
            delegate?.proxyConnectionDidClose(self)
        default:
            break
        }
    }
    
    private func startReceivingFromClient() {
        clientConnection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                self.delegate?.proxyConnectionDidFail(self, error: error)
                return
            }
            
            if let data = data, !data.isEmpty {
                print("⬆️ ProxyConnection: Forwarding \(data.count) bytes from client to server")
                self.serverConnection?.send(content: data, completion: .contentProcessed { error in
                    if let error = error {
                        print("❌ ProxyConnection: Failed to send data to server: \(error)")
                    }
                })
            }
            
            if isComplete {
                self.delegate?.proxyConnectionDidClose(self)
            } else {
                self.startReceivingFromClient()
            }
        }
    }
    
    private func startReceivingFromServer() {
        serverConnection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                self.delegate?.proxyConnectionDidFail(self, error: error)
                return
            }
            
            if let data = data, !data.isEmpty {
                print("⬇️ ProxyConnection: Forwarding \(data.count) bytes from server to client")
                self.clientConnection.send(content: data, completion: .contentProcessed { error in
                    if let error = error {
                        print("❌ ProxyConnection: Failed to send data to client: \(error)")
                    }
                })
            }
            
            if isComplete {
                self.delegate?.proxyConnectionDidClose(self)
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