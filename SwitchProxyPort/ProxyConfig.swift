import Foundation

struct ProxyConfig: Codable {
    var listenPort: Int = 8080
    var targetPorts: [Int] = [3000, 3001, 3002]
    var activeTargetPort: Int = 3000
    var isEnabled: Bool = false
    var autoStart: Bool = false
    
    static let defaultConfig = ProxyConfig()
    
    init() {
        if !targetPorts.contains(activeTargetPort) {
            activeTargetPort = targetPorts.first ?? 3000
        }
    }
    
    mutating func addTargetPort(_ port: Int) {
        if !targetPorts.contains(port) {
            targetPorts.append(port)
            targetPorts.sort()
        }
    }
    
    mutating func removeTargetPort(_ port: Int) {
        if let index = targetPorts.firstIndex(of: port) {
            targetPorts.remove(at: index)
            
            if activeTargetPort == port && !targetPorts.isEmpty {
                activeTargetPort = targetPorts.first!
            }
        }
    }
    
    func isValidTargetPort(_ port: Int) -> Bool {
        return targetPorts.contains(port)
    }
}