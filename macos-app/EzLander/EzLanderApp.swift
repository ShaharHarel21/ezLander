import SwiftUI
import AppKit

@main
struct EzLanderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (menu bar only app)
        NSApp.setActivationPolicy(.accessory)

        // Initialize menu bar controller
        menuBarController = MenuBarController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
    }
}
