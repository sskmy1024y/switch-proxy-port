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
    private var animationTimer: Timer?
    
    weak var delegate: StatusBarControllerDelegate?
    
    deinit {
        stopStatusBarAnimation()
    }
    
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
        // Start or stop animation based on enabled state
        if enabled {
            startStatusBarAnimation()
        } else {
            stopStatusBarAnimation()
        }
    }
    
    private func startStatusBarAnimation() {
        guard let button = statusItem?.button else { return }
        
        // Stop any existing animation
        stopStatusBarAnimation()
        
        // Use same base icon for both states - just the antenna icon
        let baseImage = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right", accessibilityDescription: "Switch Proxy Port")
        baseImage?.size = NSSize(width: 18, height: 18)
        baseImage?.isTemplate = true
        
        // Create a slightly different version for alternation - use a different related icon
        let alternateImage = NSImage(systemSymbolName: "wifi", accessibilityDescription: "Switch Proxy Port")
        alternateImage?.size = NSSize(width: 18, height: 18)
        alternateImage?.isTemplate = true
        
        var isShowingBase = true
        
        // Set initial state
        button.image = baseImage
        
        // Create timer for animation
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let button = self?.statusItem?.button else { return }
            
            isShowingBase.toggle()
            
            // Switch between two different icons
            if isShowingBase {
                button.image = baseImage
            } else {
                button.image = alternateImage
            }
        }
    }
    
    private func stopStatusBarAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        
        // Reset to static disabled icon
        if let button = statusItem?.button {
            let staticImage = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right", accessibilityDescription: "Switch Proxy Port")
            staticImage?.size = NSSize(width: 18, height: 18)
            staticImage?.isTemplate = true
            
            button.image = staticImage
        }
    }
    
    private func setupMenu() {
        menu = NSMenu()
        
        // Modern title with status indicator
        let titleItem = NSMenuItem(title: "SwitchProxyPort", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        
        // Add attributed title for better styling
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        titleItem.attributedTitle = NSAttributedString(string: "SwitchProxyPort", attributes: titleAttributes)
        menu?.addItem(titleItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        // Status section with better visual hierarchy - always show
        let statusSection = createStatusSection()
        menu?.addItem(statusSection)
        menu?.addItem(NSMenuItem.separator())
        
        // Toggle with modern styling and current status
        let statusLabel = config.isEnabled ? "ON" : "OFF"
        let actionLabel = config.isEnabled ? "Turn Off" : "Turn On"
        let toggleItem = NSMenuItem(
            title: "[\(statusLabel)] \(actionLabel)",
            action: #selector(toggleProxy),
            keyEquivalent: ""
        )
        toggleItem.target = self
        
        // Add keyboard shortcut
        toggleItem.keyEquivalent = "t"
        toggleItem.keyEquivalentModifierMask = [.command]
        
        menu?.addItem(toggleItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        // Target ports with better organization
        createTargetPortsSection()
        
        menu?.addItem(NSMenuItem.separator())
        
        // Preferences with icon
        let preferencesItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(showPreferences),
            keyEquivalent: ","
        )
        preferencesItem.target = self
        preferencesItem.image = NSImage(systemSymbolName: "gear", accessibilityDescription: "Preferences")
        menu?.addItem(preferencesItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        // Quit with standard shortcut
        let quitItem = NSMenuItem(
            title: "Quit SwitchProxyPort",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: "Quit")
        menu?.addItem(quitItem)
    }
    
    private func createStatusSection() -> NSMenuItem {
        let statusItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        
        let statusIndicator = config.isEnabled ? "🟢 ACTIVE" : "⚪ INACTIVE"
        let statusText = """
        \(statusIndicator)
        📡 Listen Port: localhost:\(config.listenPort)
        🎯 Target Port: localhost:\(config.activeTargetPort)
        """
        
        let statusColor = config.isEnabled ? NSColor.secondaryLabelColor : NSColor.tertiaryLabelColor
        let statusAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: statusColor
        ]
        
        statusItem.attributedTitle = NSAttributedString(string: statusText, attributes: statusAttributes)
        return statusItem
    }
    
    private func createTargetPortsSection() {
        let portsSubmenu = NSMenu()
        
        // Add header
        let headerItem = NSMenuItem(title: "Select Target Port", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        headerItem.attributedTitle = NSAttributedString(string: "Select Target Port", attributes: headerAttributes)
        portsSubmenu.addItem(headerItem)
        portsSubmenu.addItem(NSMenuItem.separator())
        
        // Add port options
        for (index, port) in config.targetPorts.enumerated() {
            let isActive = port == config.activeTargetPort
            let prefix = isActive ? "● " : "○ "
            let portItem = NSMenuItem(
                title: "\(prefix)localhost:\(port)",
                action: #selector(selectTargetPort(_:)),
                keyEquivalent: index < 9 ? "\(index + 1)" : ""
            )
            portItem.target = self
            portItem.tag = port
            portItem.state = isActive ? .on : .off
            
            // Style active port differently
            if isActive {
                let activeAttributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                    .foregroundColor: NSColor.controlAccentColor
                ]
                portItem.attributedTitle = NSAttributedString(string: "\(prefix)localhost:\(port)", attributes: activeAttributes)
            } else {
                let normalAttributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 13, weight: .regular),
                    .foregroundColor: NSColor.labelColor
                ]
                portItem.attributedTitle = NSAttributedString(string: "\(prefix)localhost:\(port)", attributes: normalAttributes)
            }
            
            portsSubmenu.addItem(portItem)
        }
        
        let portsMenuItem = NSMenuItem(title: "🎯 Target Ports", action: nil, keyEquivalent: "")
        portsMenuItem.submenu = portsSubmenu
        menu?.addItem(portsMenuItem)
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