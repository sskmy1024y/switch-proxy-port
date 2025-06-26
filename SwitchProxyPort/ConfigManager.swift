import Foundation

class ConfigManager {
    static let shared = ConfigManager()
    
    private let userDefaults = UserDefaults.standard
    private let configKey = "ProxyConfig"
    
    private init() {}
    
    func load() -> ProxyConfig {
        if let data = userDefaults.data(forKey: configKey),
           let config = try? JSONDecoder().decode(ProxyConfig.self, from: data) {
            return config
        }
        return ProxyConfig.defaultConfig
    }
    
    func save(_ config: ProxyConfig) {
        if let data = try? JSONEncoder().encode(config) {
            userDefaults.set(data, forKey: configKey)
        }
    }
    
    func reset() {
        userDefaults.removeObject(forKey: configKey)
    }
    
    func addTargetPort(_ port: Int) {
        var config = load()
        config.addTargetPort(port)
        save(config)
    }
    
    func removeTargetPort(_ port: Int) {
        var config = load()
        config.removeTargetPort(port)
        save(config)
    }
    
    func setActiveTargetPort(_ port: Int) {
        var config = load()
        if config.isValidTargetPort(port) {
            config.activeTargetPort = port
            save(config)
        }
    }
    
    func toggleProxyEnabled() {
        var config = load()
        config.isEnabled.toggle()
        save(config)
    }
}