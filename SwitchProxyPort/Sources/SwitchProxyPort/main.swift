import Cocoa
import Foundation

// Set up crash handler
var shouldTerminate = false

signal(SIGTERM) { _ in
    shouldTerminate = true
    DispatchQueue.main.async {
        print("Received SIGTERM, shutting down gracefully...")
        NSApplication.shared.terminate(nil)
    }
}

signal(SIGINT) { _ in
    shouldTerminate = true
    DispatchQueue.main.async {
        print("Received SIGINT, shutting down gracefully...")
        NSApplication.shared.terminate(nil)
    }
}

// Set up exception handler
NSSetUncaughtExceptionHandler { exception in
    print("⚠️ Uncaught exception: \(exception)")
    print("Stack trace: \(exception.callStackSymbols)")
    
    // Try to save state before crashing
    if let delegate = NSApplication.shared.delegate as? AppDelegate {
        delegate.applicationWillTerminate(Notification(name: Notification.Name("AppCrash")))
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

app.setActivationPolicy(.accessory)
app.run()