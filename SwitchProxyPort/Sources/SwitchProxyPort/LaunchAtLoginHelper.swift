import Foundation
import ServiceManagement

class LaunchAtLoginHelper {
    static let shared = LaunchAtLoginHelper()
    
    private init() {}
    
    var isEnabled: Bool {
        get {
            return getLoginItemStatus()
        }
        set {
            setLoginItemStatus(enabled: newValue)
        }
    }
    
    private func getLoginItemStatus() -> Bool {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return false
        }
        
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            // Legacy method for older macOS versions
            let loginItems = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil)
            guard let loginItemsRef = loginItems?.takeRetainedValue() else {
                return false
            }
            
            let loginItemsArray = LSSharedFileListCopySnapshot(loginItemsRef, nil)
            guard let loginItemsSnapshot = loginItemsArray?.takeRetainedValue() as? [LSSharedFileListItem] else {
                return false
            }
            
            let bundleURL = Bundle.main.bundleURL
            
            for item in loginItemsSnapshot {
                if let itemURL = LSSharedFileListItemCopyResolvedURL(item, 0, nil)?.takeRetainedValue() as URL? {
                    if itemURL == bundleURL {
                        return true
                    }
                }
            }
            
            return false
        }
    }
    
    private func setLoginItemStatus(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            }
        } else {
            // Legacy method for older macOS versions
            setLegacyLoginItemStatus(enabled: enabled)
        }
    }
    
    private func setLegacyLoginItemStatus(enabled: Bool) {
        let bundleURL = Bundle.main.bundleURL
        let loginItems = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil)
        
        guard let loginItemsRef = loginItems?.takeRetainedValue() else {
            return
        }
        
        if enabled {
            // Add to login items
            LSSharedFileListInsertItemURL(
                loginItemsRef,
                kLSSharedFileListItemBeforeFirst.takeRetainedValue(),
                nil,
                nil,
                bundleURL as CFURL,
                nil,
                nil
            )
        } else {
            // Remove from login items
            let loginItemsArray = LSSharedFileListCopySnapshot(loginItemsRef, nil)
            guard let loginItemsSnapshot = loginItemsArray?.takeRetainedValue() as? [LSSharedFileListItem] else {
                return
            }
            
            for item in loginItemsSnapshot {
                if let itemURL = LSSharedFileListItemCopyResolvedURL(item, 0, nil)?.takeRetainedValue() as URL? {
                    if itemURL == bundleURL {
                        LSSharedFileListItemRemove(loginItemsRef, item)
                        break
                    }
                }
            }
        }
    }
}