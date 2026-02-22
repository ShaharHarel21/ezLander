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
        // Show dock icon alongside menu bar
        NSApp.setActivationPolicy(.regular)

        // Initialize menu bar controller
        menuBarController = MenuBarController()

        // Register for URL events
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // When user clicks the Dock icon, show the popover
        menuBarController?.showPopover()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
    }

    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else {
            return
        }

        print("App received URL: \(url)")

        // Handle OAuth callback
        if url.scheme == "com.ezlander.app" {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let state = components?.queryItems?.first(where: { $0.name == "state" })?.value
            if state == "claude" {
                ClaudeOAuthService.shared.handleCallback(url: url)
            } else {
                OAuthService.shared.handleCallback(url: url)
            }
        }
    }
}
