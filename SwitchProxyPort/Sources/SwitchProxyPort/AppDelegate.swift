import Cocoa
import Network
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var popoverController: PopoverController?
    private var proxyServer: ProxyServer?
    private var configManager = ConfigManager.shared
    private var errorNotificationTimer: Timer?
    private var lastErrorTime: Date?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupUI()
        loadConfiguration()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        proxyServer?.stop()
    }
    
    
    private func setupUI() {
        proxyServer = ProxyServer()
        proxyServer?.delegate = self
        
        popoverController = PopoverController(
            proxyServer: proxyServer!,
            configManager: configManager
        )
    }
    
    private func loadConfiguration() {
        let config = configManager.currentConfig
        
        // 自動有効化が設定されている場合はプロキシを有効にする
        if config.autoStart && !config.isEnabled {
            configManager.toggleProxyEnabled()
        }
        
        updateProxyServer(with: configManager.currentConfig)
    }
    
    private func updateProxyServer(with config: ProxyConfig) {
        if config.isEnabled {
            proxyServer?.start(listenPort: config.listenPort, targetPort: config.currentTargetPort)
        } else {
            proxyServer?.stop()
        }
    }
}

extension AppDelegate: ProxyServerDelegate {
    func proxyServerDidStart(on port: Int) {
        print("Proxy server started on port \(port)")
    }
    
    func proxyServerDidStop() {
        print("Proxy server stopped")
    }
    
    func proxyServerDidFailToStart(_ error: Error) {
        print("Proxy server failed to start: \(error)")
        configManager.currentConfig.isEnabled = false
        configManager.saveConfig()
    }
    
    func proxyServerDidSwitchTarget(to port: Int) {
        print("Proxy server switched target to port \(port)")
    }
    
    func proxyServerDidEncounterError(_ error: Error) {
        print("Proxy server error: \(error)")
        // Don't show notifications for individual errors - auto-recovery will handle them
    }
    
    func proxyServerDidRecover(after attempt: Int) {
        print("✅ Proxy server recovered after \(attempt) attempt(s)")
    }
    
    func proxyServerWillRestart(attempt: Int, maxAttempts: Int) {
        print("🔄 Proxy server restarting (attempt \(attempt)/\(maxAttempts))")
    }
    
    @objc private func handleCrash() {
        // Log crash information
        print("❌ Application crash detected. Attempting recovery...")
        
        // Stop and restart proxy server
        proxyServer?.stop()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            self.updateProxyServer(with: self.configManager.currentConfig)
        }
    }
}

