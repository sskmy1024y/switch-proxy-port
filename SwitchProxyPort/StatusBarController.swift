import Cocoa

protocol StatusBarControllerDelegate: AnyObject {
    func didToggleProxy(enabled: Bool)
    func didSelectTargetPort(_ port: Int)
    func didRequestPreferences()
    func didRequestQuit()
}

class StatusBarController {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var config: ProxyConfig = ProxyConfig.defaultConfig
    
    weak var delegate: StatusBarControllerDelegate?
    
    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right", accessibilityDescription: "Switch Proxy Port")
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
        }
        
        setupMenu()
        statusItem?.menu = menu
    }
    
    func updateMenu(with config: ProxyConfig) {
        self.config = config
        setupMenu()
        updateIcon(enabled: config.isEnabled)
    }
    
    func updateIcon(enabled: Bool) {
        guard let button = statusItem?.button else { return }
        
        let iconName = enabled ? "antenna.radiowaves.left.and.right.circle" : "antenna.radiowaves.left.and.right"
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Switch Proxy Port")
        button.image?.size = NSSize(width: 18, height: 18)
        button.image?.isTemplate = true
    }
    
    private func setupMenu() {
        menu = NSMenu()
        
        let titleItem = NSMenuItem(title: "Switch Proxy Port", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu?.addItem(titleItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        let toggleItem = NSMenuItem(
            title: config.isEnabled ? "Turn Off" : "Turn On",
            action: #selector(toggleProxy),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu?.addItem(toggleItem)
        
        if config.isEnabled {
            menu?.addItem(NSMenuItem.separator())
            
            let statusItem = NSMenuItem(
                title: "Listening on port \(config.listenPort)",
                action: nil,
                keyEquivalent: ""
            )
            statusItem.isEnabled = false
            menu?.addItem(statusItem)
            
            let activeItem = NSMenuItem(
                title: "Forwarding to port \(config.activeTargetPort)",
                action: nil,
                keyEquivalent: ""
            )
            activeItem.isEnabled = false
            menu?.addItem(activeItem)
        }
        
        menu?.addItem(NSMenuItem.separator())
        
        let portsSubmenu = NSMenu()
        for port in config.targetPorts {
            let portItem = NSMenuItem(
                title: "Port \(port)",
                action: #selector(selectTargetPort(_:)),
                keyEquivalent: ""
            )
            portItem.target = self
            portItem.tag = port
            portItem.state = (port == config.activeTargetPort) ? .on : .off
            portsSubmenu.addItem(portItem)
        }
        
        let portsMenuItem = NSMenuItem(title: "Target Ports", action: nil, keyEquivalent: "")
        portsMenuItem.submenu = portsSubmenu
        menu?.addItem(portsMenuItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        let preferencesItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(showPreferences),
            keyEquivalent: ","
        )
        preferencesItem.target = self
        menu?.addItem(preferencesItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu?.addItem(quitItem)
    }
    
    @objc private func toggleProxy() {
        delegate?.didToggleProxy(enabled: !config.isEnabled)
    }
    
    @objc private func selectTargetPort(_ sender: NSMenuItem) {
        delegate?.didSelectTargetPort(sender.tag)
    }
    
    @objc private func showPreferences() {
        delegate?.didRequestPreferences()
    }
    
    @objc private func quit() {
        delegate?.didRequestQuit()
    }
}