import Foundation
import Network

class ProxyServer {
    private var listener: NWListener?
    private var connections: Set<ProxyConnection> = []
    private var isRunning = false
    
    private var listenPort: Int = 8080
    private var targetPort: Int = 3000
    private let queue = DispatchQueue(label: "proxy-server", qos: .utility)
    
    weak var delegate: ProxyServerDelegate?
    
    func start(listenPort: Int, targetPort: Int) {
        guard !isRunning else { return }
        
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
        
        isRunning = false
        delegate?.proxyServerDidStop()
    }
    
    func switchTarget(to port: Int) {
        self.targetPort = port
        delegate?.proxyServerDidSwitchTarget(to: port)
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        let proxyConnection = ProxyConnection(
            clientConnection: connection,
            targetHost: "127.0.0.1",
            targetPort: targetPort,
            queue: queue
        )
        
        proxyConnection.delegate = self
        connections.insert(proxyConnection)
        proxyConnection.start()
    }
    
    private func handleListenerStateUpdate(_ state: NWListener.State) {
        switch state {
        case .ready:
            isRunning = true
            delegate?.proxyServerDidStart(on: listenPort)
        case .failed(let error):
            isRunning = false
            delegate?.proxyServerDidFailToStart(error)
        case .cancelled:
            isRunning = false
            delegate?.proxyServerDidStop()
        default:
            break
        }
    }
}

extension ProxyServer: ProxyConnectionDelegate {
    func proxyConnectionDidClose(_ connection: ProxyConnection) {
        connections.remove(connection)
    }
    
    func proxyConnectionDidFail(_ connection: ProxyConnection, error: Error) {
        connections.remove(connection)
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