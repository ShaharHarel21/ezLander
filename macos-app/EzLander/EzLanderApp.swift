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
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Show dock icon alongside menu bar
        NSApp.setActivationPolicy(.regular)

        // Initialize menu bar controller
        menuBarController = MenuBarController()

        // Show onboarding for new users
        if !UserDefaults.standard.bool(forKey: "onboardingComplete") {
            showOnboarding()
        }

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

    private func showOnboarding() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Welcome to ezLander"
        window.isReleasedWhenClosed = false

        let onboardingView = OnboardingView(isOnboardingComplete: Binding(
            get: { UserDefaults.standard.bool(forKey: "onboardingComplete") },
            set: { [weak self] complete in
                if complete {
                    self?.onboardingWindow?.close()
                    self?.onboardingWindow = nil
                }
            }
        ))
        window.contentViewController = NSHostingController(rootView: onboardingView)
        window.makeKeyAndOrderFront(nil)
        onboardingWindow = window
    }

    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else {
            return
        }

        print("App received URL callback (scheme: \(url.scheme ?? "nil"))")

        // Handle OAuth callback
        if url.scheme == "com.ezlander.app" {
            OAuthService.shared.handleCallback(url: url)
        }
    }
}
