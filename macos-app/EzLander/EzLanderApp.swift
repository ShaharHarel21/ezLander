import SwiftUI
import AppKit

@main
struct EzLanderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some Scene {
        Settings {
            SettingsView()
                .preferredColorScheme(themeManager.resolvedColorScheme)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController?
    static var isPreviewMode: Bool {
        CommandLine.arguments.contains("--preview-mode")
    }

    static func previewLog(_ msg: String) {
        let line = "[PREVIEW] \(msg)\n"
        let logPath = "/tmp/ezlander-preview.log"
        if let handle = FileHandle(forWritingAtPath: logPath) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: logPath, contents: line.data(using: .utf8))
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Show dock icon alongside menu bar
        NSApp.setActivationPolicy(.regular)

        // Apply saved appearance mode (light/dark/system)
        if let savedAppearance = UserDefaults.standard.string(forKey: "appearance_mode"),
           let mode = AppearanceMode(rawValue: savedAppearance) {
            mode.apply()
        }

        // Initialize menu bar controller
        menuBarController = MenuBarController()

        // In preview mode, auto-open the popover for screenshot capture
        if Self.isPreviewMode {
            Self.previewLog("Preview mode detected, will show window in 1s. Args: \(CommandLine.arguments)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                Self.previewLog("Timer fired, calling showPopover")
                self?.menuBarController?.showPopover()
            }
        }

        if !Self.isPreviewMode {
            Task { [weak self] in
                let isLicensed = await SubscriptionService.shared.checkSubscriptionOnLaunch()
                await MainActor.run {
                    let shouldShowAccess = !isLicensed
                        || !ProxyAIService.shared.isAuthenticated
                        || !UserDefaults.standard.bool(forKey: "onboardingComplete")

                    if shouldShowAccess {
                        self?.menuBarController?.showPopover()
                    }
                }
            }
        }

        // Listen for subscription invalidation during runtime
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(subscriptionInvalidated),
            name: SubscriptionService.subscriptionInvalidatedNotification,
            object: nil
        )

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

    @objc private func subscriptionInvalidated() {
        DispatchQueue.main.async { [weak self] in
            self?.menuBarController?.closePopover()
            self?.menuBarController?.showPopover()
        }
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
