import Foundation
import SwiftUI

class ConfigManager: ObservableObject {
    static let shared = ConfigManager()
    
    private let userDefaults = UserDefaults.standard
    private let configKey = "ProxyConfig"
    
    @Published var currentConfig: ProxyConfig {
        didSet {
            saveConfig()
        }
    }
    
    private init() {
        if let data = userDefaults.data(forKey: configKey),
           let config = try? JSONDecoder().decode(ProxyConfig.self, from: data) {
            self.currentConfig = config
        } else {
            self.currentConfig = ProxyConfig.defaultConfig
        }
    }
    
    func saveConfig() {
        if let data = try? JSONEncoder().encode(currentConfig) {
            userDefaults.set(data, forKey: configKey)
        }
    }
    
    func reset() {
        userDefaults.removeObject(forKey: configKey)
        currentConfig = ProxyConfig.defaultConfig
    }
    
    func addTargetPort(_ port: Int) {
        currentConfig.addTargetPort(port)
    }
    
    func removeTargetPort(_ port: Int) {
        currentConfig.removeTargetPort(port)
    }
    
    func setActiveTargetPort(_ port: Int) {
        if currentConfig.isValidTargetPort(port) {
            currentConfig.currentTargetPort = port
        }
    }
    
    func toggleProxyEnabled() {
        currentConfig.isEnabled.toggle()
    }
    
    func setAutoStart(_ enabled: Bool) {
        currentConfig.autoStart = enabled
    }
}