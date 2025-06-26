import Cocoa

protocol ModernPreferencesWindowControllerDelegate: AnyObject {
    func preferencesDidUpdate()
}

class ModernPreferencesWindowController: NSWindowController {
    weak var delegate: ModernPreferencesWindowControllerDelegate?
    var configManager = ConfigManager.shared
    var proxyServer: ProxyServer?
    
    // UI Components
    private var stackView: NSStackView!
    private var listenPortTextField: NSTextField!
    private var targetPortsTableView: NSTableView!
    private var addPortTextField: NSTextField!
    private var autoStartCheckbox: NSButton!
    private var statusLabel: NSTextField!
    
    private var targetPorts: [Int] = []
    
    convenience init() {
        // Modern window with proper sizing and style
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.title = "SwitchProxyPort Preferences"
        window.subtitle = "Configure proxy server settings"
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible
        
        // Modern macOS window appearance
        if #available(macOS 11.0, *) {
            window.toolbarStyle = .unified
        }
        
        window.center()
        self.init(window: window)
        setupModernUI()
        loadSettings()
    }
    
    private func setupModernUI() {
        guard let contentView = window?.contentView else { return }
        
        // Set up the main container with proper margins
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
        
        // Main stack view for organized layout
        stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 24
        stackView.alignment = .leading
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stackView)
        
        // Header section
        createHeaderSection()
        
        // Listen port section
        createListenPortSection()
        
        // Target ports section
        createTargetPortsSection()
        
        // Settings section
        createSettingsSection()
        
        // Status section
        createStatusSection()
        
        // Button section
        createButtonSection()
        
        // Layout constraints
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 52), // Account for title bar
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),
            
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor)
        ])
    }
    
    private func createHeaderSection() {
        let headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        
        let iconImageView = NSImageView()
        iconImageView.image = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right", accessibilityDescription: "Proxy Icon")
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = NSTextField(labelWithString: "Proxy Server Configuration")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .labelColor
        
        let descriptionLabel = NSTextField(labelWithString: "Configure your proxy server settings and target ports")
        descriptionLabel.font = NSFont.systemFont(ofSize: 13)
        descriptionLabel.textColor = .secondaryLabelColor
        
        let textStack = NSStackView(views: [titleLabel, descriptionLabel])
        textStack.orientation = .vertical
        textStack.spacing = 4
        textStack.alignment = .leading
        
        let headerStack = NSStackView(views: [iconImageView, textStack])
        headerStack.orientation = .horizontal
        headerStack.spacing = 12
        headerStack.alignment = .centerY
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(headerStack)
        
        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 32),
            iconImageView.heightAnchor.constraint(equalToConstant: 32),
            headerStack.topAnchor.constraint(equalTo: headerView.topAnchor),
            headerStack.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            headerStack.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            headerStack.bottomAnchor.constraint(equalTo: headerView.bottomAnchor)
        ])
        
        stackView.addArrangedSubview(headerView)
    }
    
    private func createListenPortSection() {
        let sectionView = createSectionContainer(title: "Listen Port", description: "Port number for the proxy server to listen on")
        
        let portStack = NSStackView()
        portStack.orientation = .horizontal
        portStack.spacing = 8
        portStack.alignment = .centerY
        
        listenPortTextField = NSTextField()
        listenPortTextField.placeholderString = "8080"
        listenPortTextField.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        listenPortTextField.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure number formatter to prevent comma formatting
        let listenPortFormatter = NumberFormatter()
        listenPortFormatter.numberStyle = .none
        listenPortFormatter.allowsFloats = false
        listenPortFormatter.minimum = 1
        listenPortFormatter.maximum = 65535
        listenPortTextField.formatter = listenPortFormatter
        
        let portLabel = NSTextField(labelWithString: ":")
        portLabel.font = NSFont.systemFont(ofSize: 13)
        portLabel.textColor = .secondaryLabelColor
        
        portStack.addArrangedSubview(NSTextField(labelWithString: "localhost"))
        portStack.addArrangedSubview(portLabel)
        portStack.addArrangedSubview(listenPortTextField)
        
        NSLayoutConstraint.activate([
            listenPortTextField.widthAnchor.constraint(equalToConstant: 80)
        ])
        
        sectionView.addArrangedSubview(portStack)
        stackView.addArrangedSubview(sectionView)
    }
    
    private func createTargetPortsSection() {
        let sectionView = createSectionContainer(title: "Target Ports", description: "Ports to forward traffic to")
        
        // Table view with modern styling
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .lineBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        targetPortsTableView = NSTableView()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("port"))
        column.title = "Port"
        column.width = 200
        targetPortsTableView.addTableColumn(column)
        targetPortsTableView.headerView = nil
        targetPortsTableView.dataSource = self
        targetPortsTableView.delegate = self
        targetPortsTableView.allowsEmptySelection = false
        targetPortsTableView.selectionHighlightStyle = .regular
        
        scrollView.documentView = targetPortsTableView
        
        // Add/Remove controls
        let controlsStack = NSStackView()
        controlsStack.orientation = .horizontal
        controlsStack.spacing = 8
        controlsStack.alignment = .centerY
        
        addPortTextField = NSTextField()
        addPortTextField.placeholderString = "3000"
        addPortTextField.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        
        // Configure number formatter to prevent comma formatting
        let addPortFormatter = NumberFormatter()
        addPortFormatter.numberStyle = .none
        addPortFormatter.allowsFloats = false
        addPortFormatter.minimum = 1
        addPortFormatter.maximum = 65535
        addPortTextField.formatter = addPortFormatter
        
        let addButton = NSButton()
        addButton.title = "Add"
        addButton.bezelStyle = .rounded
        addButton.target = self
        addButton.action = #selector(addPort)
        
        let removeButton = NSButton()
        removeButton.title = "Remove"
        removeButton.bezelStyle = .rounded
        removeButton.target = self
        removeButton.action = #selector(removePort)
        
        controlsStack.addArrangedSubview(addPortTextField)
        controlsStack.addArrangedSubview(addButton)
        controlsStack.addArrangedSubview(removeButton)
        controlsStack.addArrangedSubview(NSView()) // Spacer
        
        NSLayoutConstraint.activate([
            scrollView.heightAnchor.constraint(equalToConstant: 120),
            addPortTextField.widthAnchor.constraint(equalToConstant: 80)
        ])
        
        sectionView.addArrangedSubview(scrollView)
        sectionView.addArrangedSubview(controlsStack)
        stackView.addArrangedSubview(sectionView)
    }
    
    private func createSettingsSection() {
        let sectionView = createSectionContainer(title: "General", description: "Application behavior settings")
        
        autoStartCheckbox = NSButton()
        autoStartCheckbox.setButtonType(.switch)
        autoStartCheckbox.title = "Start automatically when you log in"
        autoStartCheckbox.font = NSFont.systemFont(ofSize: 13)
        
        sectionView.addArrangedSubview(autoStartCheckbox)
        stackView.addArrangedSubview(sectionView)
    }
    
    private func createStatusSection() {
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.isHidden = true
        
        stackView.addArrangedSubview(statusLabel)
    }
    
    private func createButtonSection() {
        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 12
        buttonStack.alignment = .centerY
        buttonStack.distribution = .gravityAreas
        
        // Spacer to push buttons to the right
        let spacer = NSView()
        buttonStack.addArrangedSubview(spacer)
        
        let cancelButton = NSButton()
        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelSettings)
        
        let saveButton = NSButton()
        saveButton.title = "Save"
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\\r" // Return key
        saveButton.target = self
        saveButton.action = #selector(saveSettings)
        
        // Make save button prominent
        if #available(macOS 11.0, *) {
            saveButton.hasDestructiveAction = false
            saveButton.controlSize = .regular
        }
        
        buttonStack.addArrangedSubview(cancelButton)
        buttonStack.addArrangedSubview(saveButton)
        
        stackView.addArrangedSubview(buttonStack)
    }
    
    private func createSectionContainer(title: String, description: String) -> NSStackView {
        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 8
        container.alignment = .leading
        
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .labelColor
        
        let descLabel = NSTextField(labelWithString: description)
        descLabel.font = NSFont.systemFont(ofSize: 11)
        descLabel.textColor = .secondaryLabelColor
        
        container.addArrangedSubview(titleLabel)
        container.addArrangedSubview(descLabel)
        
        return container
    }
    
    private func loadSettings() {
        let config = configManager.currentConfig
        listenPortTextField.intValue = Int32(config.listenPort)
        targetPorts = config.targetPorts
        autoStartCheckbox.state = config.autoStart ? .on : .off
        targetPortsTableView.reloadData()
    }
    
    private func showStatus(_ message: String, isError: Bool = false) {
        statusLabel.stringValue = message
        statusLabel.textColor = isError ? .systemRed : .systemGreen
        statusLabel.isHidden = false
        
        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.statusLabel.isHidden = true
        }
    }
    
    @objc private func addPort() {
        let port = Int(addPortTextField.intValue)
        
        guard port > 0 && port <= 65535 else {
            showStatus("Port must be between 1 and 65535", isError: true)
            return
        }
        
        guard !targetPorts.contains(port) else {
            showStatus("Port \(port) already exists", isError: true)
            return
        }
        
        targetPorts.append(port)
        targetPorts.sort()
        targetPortsTableView.reloadData()
        addPortTextField.stringValue = ""
        showStatus("Port \(port) added successfully")
    }
    
    @objc private func removePort() {
        let selectedRow = targetPortsTableView.selectedRow
        guard selectedRow >= 0 && selectedRow < targetPorts.count else {
            showStatus("Please select a port to remove", isError: true)
            return
        }
        
        let removedPort = targetPorts[selectedRow]
        targetPorts.remove(at: selectedRow)
        targetPortsTableView.reloadData()
        showStatus("Port \(removedPort) removed successfully")
    }
    
    @objc private func saveSettings() {
        let listenPort = Int(listenPortTextField.intValue)
        guard listenPort > 0 && listenPort <= 65535 else {
            showStatus("Invalid listen port number", isError: true)
            return
        }
        
        guard !targetPorts.isEmpty else {
            showStatus("At least one target port is required", isError: true)
            return
        }
        
        configManager.currentConfig.listenPort = listenPort
        configManager.currentConfig.targetPorts = targetPorts
        configManager.currentConfig.autoStart = autoStartCheckbox.state == .on
        
        // Ensure active target port is valid
        if !configManager.currentConfig.targetPorts.contains(configManager.currentConfig.currentTargetPort) {
            configManager.currentConfig.currentTargetPort = configManager.currentConfig.targetPorts.first!
        }
        
        delegate?.preferencesDidUpdate()
        showStatus("Settings saved successfully")
        
        // Close after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.close()
        }
    }
    
    @objc private func cancelSettings() {
        close()
    }
}

// MARK: - Table View Data Source & Delegate
extension ModernPreferencesWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return targetPorts.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellIdentifier = NSUserInterfaceItemIdentifier("ModernPortCell")
        
        var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
        
        if cellView == nil {
            cellView = NSTableCellView()
            cellView?.identifier = cellIdentifier
            
            let textField = NSTextField()
            textField.isBordered = false
            textField.isEditable = false
            textField.backgroundColor = .clear
            textField.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
            cellView?.addSubview(textField)
            cellView?.textField = textField
            
            textField.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                textField.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor),
                textField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 8),
                textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -8)
            ])
        }
        
        if row < targetPorts.count {
            cellView?.textField?.stringValue = String(targetPorts[row])
        }
        
        return cellView
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 24
    }
}