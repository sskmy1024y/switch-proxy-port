import Cocoa
import Network
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var popoverController: PopoverController?
    private var proxyServer: ProxyServer?
    private var configManager = ConfigManager.shared
    
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
        updateProxyServer(with: config)
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
    }
}

