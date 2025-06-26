import Cocoa
import Network

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusBarController: StatusBarController?
    private var proxyServer: ProxyServer?
    private var configManager = ConfigManager.shared
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupApplication()
        setupStatusBar()
        loadConfiguration()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        proxyServer?.stop()
    }
    
    private func setupApplication() {
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func setupStatusBar() {
        statusBarController = StatusBarController()
        statusBarController?.delegate = self
        statusBarController?.setupStatusBar()
    }
    
    private func loadConfiguration() {
        let config = configManager.load()
        updateProxyServer(with: config)
        statusBarController?.updateMenu(with: config)
    }
    
    private func updateProxyServer(with config: ProxyConfig) {
        if proxyServer == nil {
            proxyServer = ProxyServer()
            proxyServer?.delegate = self
        }
        
        if config.isEnabled {
            proxyServer?.start(listenPort: config.listenPort, targetPort: config.activeTargetPort)
        } else {
            proxyServer?.stop()
        }
    }
}

extension AppDelegate: StatusBarControllerDelegate {
    func didToggleProxy(enabled: Bool) {
        var config = configManager.load()
        config.isEnabled = enabled
        configManager.save(config)
        updateProxyServer(with: config)
        statusBarController?.updateMenu(with: config)
    }
    
    func didSelectTargetPort(_ port: Int) {
        var config = configManager.load()
        config.activeTargetPort = port
        configManager.save(config)
        
        if config.isEnabled {
            proxyServer?.switchTarget(to: port)
        }
        
        statusBarController?.updateMenu(with: config)
    }
    
    func didRequestPreferences() {
        // TODO: Show preferences window
        print("Preferences requested")
    }
    
    func didRequestQuit() {
        NSApplication.shared.terminate(nil)
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
        var config = configManager.load()
        config.isEnabled = false
        configManager.save(config)
        statusBarController?.updateMenu(with: config)
    }
    
    func proxyServerDidSwitchTarget(to port: Int) {
        print("Proxy server switched target to port \(port)")
    }
    
    func proxyServerDidEncounterError(_ error: Error) {
        print("Proxy server error: \(error)")
    }
}