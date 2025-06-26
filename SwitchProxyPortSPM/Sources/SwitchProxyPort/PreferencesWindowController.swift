import Cocoa

protocol PreferencesWindowControllerDelegate: AnyObject {
    func preferencesDidUpdate()
}

class PreferencesWindowController: NSWindowController {
    weak var delegate: PreferencesWindowControllerDelegate?
    private var configManager = ConfigManager.shared
    
    private var listenPortTextField: NSTextField!
    private var targetPortsTableView: NSTableView!
    private var addPortTextField: NSTextField!
    private var autoStartCheckbox: NSButton!
    
    private var targetPorts: [Int] = []
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preferences"
        window.isReleasedWhenClosed = false
        window.center()
        
        self.init(window: window)
        setupUI()
        loadSettings()
    }
    
    private func setupUI() {
        let contentView = NSView(frame: window!.contentView!.bounds)
        window!.contentView = contentView
        
        // Listen Port
        let listenPortLabel = NSTextField(labelWithString: "Listen Port:")
        listenPortLabel.frame = NSRect(x: 20, y: 250, width: 100, height: 20)
        contentView.addSubview(listenPortLabel)
        
        listenPortTextField = NSTextField(frame: NSRect(x: 130, y: 250, width: 100, height: 20))
        
        // Configure number formatter to prevent comma formatting
        let listenPortFormatter = NumberFormatter()
        listenPortFormatter.numberStyle = .none
        listenPortFormatter.allowsFloats = false
        listenPortFormatter.minimum = 1
        listenPortFormatter.maximum = 65535
        listenPortTextField.formatter = listenPortFormatter
        
        contentView.addSubview(listenPortTextField)
        
        // Target Ports
        let targetPortsLabel = NSTextField(labelWithString: "Target Ports:")
        targetPortsLabel.frame = NSRect(x: 20, y: 220, width: 100, height: 20)
        contentView.addSubview(targetPortsLabel)
        
        // Table View for target ports
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 120, width: 200, height: 100))
        targetPortsTableView = NSTableView()
        targetPortsTableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("port")))
        targetPortsTableView.tableColumns[0].title = "Port"
        targetPortsTableView.headerView = nil
        targetPortsTableView.dataSource = self
        targetPortsTableView.delegate = self
        scrollView.documentView = targetPortsTableView
        contentView.addSubview(scrollView)
        
        // Add port controls
        let addPortLabel = NSTextField(labelWithString: "Add Port:")
        addPortLabel.frame = NSRect(x: 240, y: 190, width: 70, height: 20)
        contentView.addSubview(addPortLabel)
        
        addPortTextField = NSTextField(frame: NSRect(x: 240, y: 165, width: 80, height: 20))
        
        // Configure number formatter to prevent comma formatting
        let addPortFormatter = NumberFormatter()
        addPortFormatter.numberStyle = .none
        addPortFormatter.allowsFloats = false
        addPortFormatter.minimum = 1
        addPortFormatter.maximum = 65535
        addPortTextField.formatter = addPortFormatter
        
        contentView.addSubview(addPortTextField)
        
        let addButton = NSButton(frame: NSRect(x: 330, y: 165, width: 50, height: 20))
        addButton.title = "Add"
        addButton.bezelStyle = .rounded
        addButton.target = self
        addButton.action = #selector(addPort)
        contentView.addSubview(addButton)
        
        let removeButton = NSButton(frame: NSRect(x: 240, y: 140, width: 80, height: 20))
        removeButton.title = "Remove"
        removeButton.bezelStyle = .rounded
        removeButton.target = self
        removeButton.action = #selector(removePort)
        contentView.addSubview(removeButton)
        
        // Auto start checkbox
        autoStartCheckbox = NSButton(frame: NSRect(x: 20, y: 80, width: 200, height: 20))
        autoStartCheckbox.setButtonType(.switch)
        autoStartCheckbox.title = "Start automatically on login"
        contentView.addSubview(autoStartCheckbox)
        
        // Buttons
        let saveButton = NSButton(frame: NSRect(x: 300, y: 20, width: 80, height: 30))
        saveButton.title = "Save"
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(saveSettings)
        contentView.addSubview(saveButton)
        
        let cancelButton = NSButton(frame: NSRect(x: 210, y: 20, width: 80, height: 30))
        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelSettings)
        contentView.addSubview(cancelButton)
    }
    
    private func loadSettings() {
        let config = configManager.currentConfig
        listenPortTextField.intValue = Int32(config.listenPort)
        targetPorts = config.targetPorts
        autoStartCheckbox.state = config.autoStart ? .on : .off
        targetPortsTableView.reloadData()
    }
    
    @objc private func addPort() {
        let port = addPortTextField.intValue
        if port > 0 && port <= 65535 && !targetPorts.contains(Int(port)) {
            targetPorts.append(Int(port))
            targetPorts.sort()
            targetPortsTableView.reloadData()
            addPortTextField.stringValue = ""
        }
    }
    
    @objc private func removePort() {
        let selectedRow = targetPortsTableView.selectedRow
        if selectedRow >= 0 && selectedRow < targetPorts.count {
            targetPorts.remove(at: selectedRow)
            targetPortsTableView.reloadData()
        }
    }
    
    @objc private func saveSettings() {
        let listenPort = Int(listenPortTextField.intValue)
        if listenPort > 0 && listenPort <= 65535 {
            configManager.currentConfig.listenPort = listenPort
        }
        
        configManager.currentConfig.targetPorts = targetPorts
        configManager.currentConfig.autoStart = autoStartCheckbox.state == .on
        
        // Ensure active target port is valid
        if !configManager.currentConfig.targetPorts.contains(configManager.currentConfig.currentTargetPort) && !configManager.currentConfig.targetPorts.isEmpty {
            configManager.currentConfig.currentTargetPort = configManager.currentConfig.targetPorts.first!
        }
        
        delegate?.preferencesDidUpdate()
        close()
    }
    
    @objc private func cancelSettings() {
        close()
    }
}

extension PreferencesWindowController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return targetPorts.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        if row < targetPorts.count {
            return targetPorts[row]
        }
        return nil
    }
}

extension PreferencesWindowController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellIdentifier = NSUserInterfaceItemIdentifier("PortCell")
        
        var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
        
        if cellView == nil {
            cellView = NSTableCellView()
            cellView?.identifier = cellIdentifier
            
            let textField = NSTextField()
            textField.isBordered = false
            textField.isEditable = false
            textField.backgroundColor = NSColor.clear
            cellView?.addSubview(textField)
            cellView?.textField = textField
            
            textField.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                textField.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor),
                textField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 5),
                textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -5)
            ])
        }
        
        if row < targetPorts.count {
            cellView?.textField?.stringValue = String(targetPorts[row])
        }
        
        return cellView
    }
}