import Cocoa
import SwiftUI

class PopoverController: NSObject {
    private var popover: NSPopover?
    private var statusItem: NSStatusItem?
    private var animationTimer: Timer?
    
    // Dependencies
    private let proxyServer: ProxyServer
    private let configManager: ConfigManager
    
    // State
    @Published var isPopoverShown = false
    
    // Binding for SwiftUI
    private var isPopoverShownBinding: Binding<Bool> {
        Binding(
            get: { self.isPopoverShown },
            set: { self.isPopoverShown = $0 }
        )
    }
    
    // Preferences window
    private var preferencesWindowController: ModernPreferencesWindowController?
    
    init(proxyServer: ProxyServer, configManager: ConfigManager) {
        self.proxyServer = proxyServer
        self.configManager = configManager
        super.init()
        
        setupStatusItem()
        setupPopover()
    }
    
    deinit {
        stopStatusBarAnimation()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            updateStatusItemIcon()
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            
            // Add visual feedback
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Observe proxy state changes
        proxyServer.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                self?.updateStatusItemIcon()
            }
        }.store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func setupPopover() {
        let contentView = PopoverContentView(
            proxyServer: proxyServer,
            configManager: configManager,
            isPopoverShown: isPopoverShownBinding,
            onPreferencesClick: { [weak self] in
                self?.showPreferences()
            },
            onQuitClick: { [weak self] in
                self?.quitApplication()
            }
        )
        
        let hostingController = NSHostingController(rootView: contentView)
        if #available(macOS 13.0, *) {
            hostingController.sizingOptions = [.preferredContentSize]
        }
        
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 280, height: 0)
        popover?.behavior = .transient
        popover?.contentViewController = hostingController
        popover?.delegate = self
        
        // Configure appearance to match SwiftUI content
        popover?.appearance = NSAppearance(named: .aqua)
        popover?.animates = true
        
        // Ensure the popover background matches the SwiftUI content
        if let popoverView = popover?.contentViewController?.view {
            popoverView.wantsLayer = true
            popoverView.layer?.cornerRadius = 16  // Match SwiftUI cornerRadius
            popoverView.layer?.masksToBounds = true
        }
    }
    
    private func updateStatusItemIcon() {
        guard let button = statusItem?.button else { return }
        
        // Start or stop animation based on proxy state
        if proxyServer.isRunning {
            startStatusBarAnimation()
        } else {
            stopStatusBarAnimation()
        }
        
        // Update tooltip
        let status = proxyServer.isRunning ? "Running" : "Stopped"
        let port = proxyServer.isRunning ? " (:\(configManager.currentConfig.listenPort) → :\(configManager.currentConfig.currentTargetPort))" : ""
        button.toolTip = "SwitchProxyPort - \(status)\(port)"
    }
    
    private func startStatusBarAnimation() {
        guard let button = statusItem?.button else { return }
        
        // Stop any existing animation
        stopStatusBarAnimation()
        
        // Use opacity animation to simulate the variableColor effect
        let baseImage = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right", accessibilityDescription: nil)
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let configuredImage = baseImage?.withSymbolConfiguration(config)
        configuredImage?.isTemplate = true
        
        guard let image = configuredImage else { return }
        
        // Set the image
        button.image = image
        
        // Create pulsing animation similar to SwiftUI's variableColor effect
        var isPulsing = false
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            guard let button = self?.statusItem?.button else { return }
            
            isPulsing.toggle()
            
            // Create a subtle opacity animation to simulate variableColor
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.4
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                button.animator().alphaValue = isPulsing ? 0.6 : 1.0
            })
        }
    }
    
    private func stopStatusBarAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        
        // Reset to static disabled icon with full opacity
        if let button = statusItem?.button {
            let staticImage = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right", accessibilityDescription: nil)
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            let configuredImage = staticImage?.withSymbolConfiguration(config)
            configuredImage?.isTemplate = true
            
            button.image = configuredImage
            button.alphaValue = 1.0  // Ensure full opacity when stopped
        }
    }
    
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let popover = popover else { return }
        
        if popover.isShown {
            hidePopover()
        } else {
            showPopover(sender)
        }
    }
    
    private func showPopover(_ sender: NSStatusBarButton) {
        guard let popover = popover else { return }
        
        // Update the binding
        isPopoverShown = true
        
        // Show popover
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        
        // Activate the app to ensure proper focus
        NSApp.activate(ignoringOtherApps: true)
        
        // Add subtle animation
        popover.contentViewController?.view.layer?.add(createShowAnimation(), forKey: "show")
    }
    
    private func hidePopover() {
        guard let popover = popover else { return }
        
        // Add subtle animation
        popover.contentViewController?.view.layer?.add(createHideAnimation(), forKey: "hide")
        
        // Hide after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            popover.performClose(nil)
            self.isPopoverShown = false
        }
    }
    
    private func createShowAnimation() -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 0.8
        animation.toValue = 1.0
        animation.duration = 0.2
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        return animation
    }
    
    private func createHideAnimation() -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 1.0
        animation.toValue = 0.95
        animation.duration = 0.1
        animation.timingFunction = CAMediaTimingFunction(name: .easeIn)
        return animation
    }
    
    private func showPreferences() {
        hidePopover()
        
        if preferencesWindowController == nil {
            preferencesWindowController = ModernPreferencesWindowController()
            preferencesWindowController?.proxyServer = proxyServer
            preferencesWindowController?.configManager = configManager
        }
        
        preferencesWindowController?.showWindow(nil)
        preferencesWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func quitApplication() {
        hidePopover()
        
        // Stop proxy server
        proxyServer.stop()
        
        // Quit application
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.terminate(nil)
        }
    }
}

// MARK: - NSPopoverDelegate
extension PopoverController: NSPopoverDelegate {
    func popoverWillShow(_ notification: Notification) {
        isPopoverShown = true
    }
    
    func popoverDidClose(_ notification: Notification) {
        isPopoverShown = false
    }
    
    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        return true
    }
}

// MARK: - NSImage Extension
extension NSImage {
    func withTintColor(_ color: NSColor) -> NSImage {
        let image = self.copy() as! NSImage
        image.lockFocus()
        
        color.set()
        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceAtop)
        
        image.unlockFocus()
        return image
    }
}

// MARK: - Combine Import
import Combine