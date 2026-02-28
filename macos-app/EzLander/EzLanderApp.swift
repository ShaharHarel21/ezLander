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

/// Prevents the user from closing onboarding/license windows without completing the flow.
class NonClosableWindowDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Block close — user must complete onboarding or license activation
        NSSound.beep()
        return false
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController?
    private var onboardingWindow: NSWindow?
    private var licenseWindow: NSWindow?
    private let windowDelegate = NonClosableWindowDelegate()
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

        // Gate: onboarding for new users, license check for returning users
        if !Self.isPreviewMode {
            if !UserDefaults.standard.bool(forKey: "onboardingComplete") {
                // First-time user: show onboarding (subscription step at end)
                showOnboarding()
            } else {
                // Returning user: check license
                Task {
                    let isLicensed = await SubscriptionService.shared.checkSubscriptionOnLaunch()
                    await MainActor.run {
                        if !isLicensed {
                            showLicenseActivation()
                        }
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

    private func showOnboarding() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Welcome to ezLander"
        window.isReleasedWhenClosed = false
        window.delegate = windowDelegate
        window.level = .floating

        let onboardingView = OnboardingView(isOnboardingComplete: Binding(
            get: { UserDefaults.standard.bool(forKey: "onboardingComplete") },
            set: { [weak self] complete in
                if complete {
                    self?.onboardingWindow?.delegate = nil
                    self?.onboardingWindow?.close()
                    self?.onboardingWindow = nil
                }
            }
        ))
        window.contentViewController = NSHostingController(rootView: onboardingView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }

    func showLicenseActivation() {
        // Don't show multiple license windows
        if licenseWindow != nil { return }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Activate ezLander"
        window.isReleasedWhenClosed = false
        window.delegate = windowDelegate
        window.level = .floating

        let licenseView = LicenseView(isLicenseActivated: Binding(
            get: { SubscriptionService.shared.isSubscribed },
            set: { [weak self] activated in
                if activated {
                    self?.licenseWindow?.delegate = nil
                    self?.licenseWindow?.close()
                    self?.licenseWindow = nil
                }
            }
        ))
        window.contentViewController = NSHostingController(rootView: licenseView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        licenseWindow = window
    }

    @objc private func subscriptionInvalidated() {
        DispatchQueue.main.async { [weak self] in
            self?.menuBarController?.closePopover()
            self?.showLicenseActivation()
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
