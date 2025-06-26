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
        connectToTarget()
        startReceivingFromClient()
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
    
    private func handleServerConnectionState(_ state: NWConnection.State) {
        switch state {
        case .ready:
            startReceivingFromServer()
        case .failed(let error):
            delegate?.proxyConnectionDidFail(self, error: error)
        case .cancelled:
            delegate?.proxyConnectionDidFail(self, error: ProxyError.connectionClosed)
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
                self.serverConnection?.send(content: data, completion: .contentProcessed { _ in })
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
                self.clientConnection.send(content: data, completion: .contentProcessed { _ in })
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