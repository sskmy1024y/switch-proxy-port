import Foundation

struct ProxyConfig: Codable {
    var listenPort: Int = 8080
    var targetPorts: [Int] = [3000, 3001, 3002]
    var currentTargetPort: Int = 3000
    var isEnabled: Bool = false
    var autoStart: Bool = false
    
    // Migration support
    var activeTargetPort: Int {
        get { currentTargetPort }
        set { currentTargetPort = newValue }
    }
    
    static let defaultConfig = ProxyConfig()
    
    init() {
        if !targetPorts.contains(currentTargetPort) {
            currentTargetPort = targetPorts.first ?? 3000
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
            
            if currentTargetPort == port && !targetPorts.isEmpty {
                currentTargetPort = targetPorts.first!
            }
        }
    }
    
    func isValidTargetPort(_ port: Int) -> Bool {
        return targetPorts.contains(port)
    }
}