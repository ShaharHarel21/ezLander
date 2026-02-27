import SwiftUI
import AppKit

// MARK: - Menu Bar Icon Options
enum MenuBarIconOption: String, CaseIterable, Identifiable {
    case starFill = "star.fill"
    case sparkle = "sparkle"
    case boltFill = "bolt.fill"
    case wandAndStars = "wand.and.stars"
    case paperplaneFill = "paperplane.fill"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .starFill: return "Star"
        case .sparkle: return "Sparkle"
        case .boltFill: return "Bolt"
        case .wandAndStars: return "Wand"
        case .paperplaneFill: return "Plane"
        }
    }
}

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: EventMonitor?
    private let shortcutService = KeyboardShortcutService.shared
    private var statusMenu: NSMenu!
    private var previewWindow: NSWindow?

    // Notification for tab switching
    static let switchTabNotification = Notification.Name("SwitchTabNotification")

    override init() {
        super.init()
        setupStatusItem()
        setupPopover()
        setupMenu()
        setupEventMonitor()
        setupKeyboardShortcuts()
        setupThemeObserver()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            updateMenuBarIcon(button: button)
            button.action = #selector(handleClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuBarIconChanged),
            name: Notification.Name("MenuBarIconChanged"),
            object: nil
        )
    }

    private func updateMenuBarIcon(button: NSStatusBarButton) {
        let iconName = UserDefaults.standard.string(forKey: "menu_bar_icon") ?? MenuBarIconOption.starFill.rawValue
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "ezLander")?.withSymbolConfiguration(config)
        image?.isTemplate = true
        button.image = image
    }

    @objc private func menuBarIconChanged() {
        if let button = statusItem.button {
            updateMenuBarIcon(button: button)
        }
    }

    private func setupMenu() {
        statusMenu = NSMenu()

        // App name header
        let appNameItem = NSMenuItem(title: "ezLander", action: nil, keyEquivalent: "")
        appNameItem.isEnabled = false
        statusMenu.addItem(appNameItem)

        // Version
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let versionItem = NSMenuItem(title: "Version \(version)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        statusMenu.addItem(versionItem)

        statusMenu.addItem(NSMenuItem.separator())

        // Check for Updates
        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        statusMenu.addItem(updateItem)

        // Open Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        statusMenu.addItem(settingsItem)

        statusMenu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit ezLander", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        statusMenu.addItem(quitItem)
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Right click - show menu
            statusItem.menu = statusMenu
            statusItem.button?.performClick(nil)
            // Reset menu so left click works normally
            DispatchQueue.main.async {
                self.statusItem.menu = nil
            }
        } else {
            // Left click - toggle popover
            togglePopover()
        }
    }

    @objc private func checkForUpdates() {
        Task {
            await UpdateService.shared.checkForUpdates()
            if UpdateService.shared.updateAvailable {
                await UpdateService.shared.downloadAndInstall()
            } else {
                await MainActor.run {
                    let alert = NSAlert()
                    alert.messageText = "You're up to date!"
                    alert.informativeText = "ezLander \(UpdateService.shared.currentVersion) is the latest version."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }

    @objc private func openSettings() {
        showPopover()
        NotificationCenter.default.post(name: Self.switchTabNotification, object: "settings")
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 500)
        // In preview mode, keep popover open for screenshot capture
        popover.behavior = AppDelegate.isPreviewMode ? .applicationDefined : .transient
        popover.contentViewController = NSHostingController(rootView: MainPopover())
    }

    private func setupEventMonitor() {
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let popover = self?.popover, popover.isShown {
                self?.closePopover()
            }
        }
    }

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    func showPopover() {
        if AppDelegate.isPreviewMode {
            showPreviewWindow()
            return
        }
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            eventMonitor?.start()
        }
    }

    private func closePopover() {
        if AppDelegate.isPreviewMode {
            // Don't close in preview mode
            return
        }
        popover.performClose(nil)
        eventMonitor?.stop()
    }

    private func showPreviewWindow() {
        AppDelegate.previewLog("showPreviewWindow called, existing=\(previewWindow != nil)")
        if previewWindow != nil { return }
        let hostingController = NSHostingController(rootView: MainPopover())
        hostingController.preferredContentSize = NSSize(width: 400, height: 500)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.setContentSize(NSSize(width: 400, height: 500))
        window.center()
        window.title = "ezLander Preview"
        window.isReleasedWhenClosed = false
        window.appearance = ThemeManager.shared.resolvedNSAppearance
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        previewWindow = window
        AppDelegate.previewLog("Preview window created. Frame=\(window.frame), isVisible=\(window.isVisible)")
    }

    private func setupKeyboardShortcuts() {
        shortcutService.onShortcutTriggered = { [weak self] action in
            DispatchQueue.main.async {
                self?.handleShortcut(action)
            }
        }
    }

    private func setupThemeObserver() {
        // Apply the initial theme to the popover
        applyThemeToPopover()

        // Listen for theme changes and update the popover's AppKit appearance
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange(_:)),
            name: ThemeManager.themeDidChangeNotification,
            object: nil
        )
    }

    @objc private func themeDidChange(_ notification: Notification) {
        applyThemeToPopover()
    }

    private func applyThemeToPopover() {
        let appearance = ThemeManager.shared.resolvedNSAppearance
        popover.appearance = appearance
        popover.contentViewController?.view.appearance = appearance
        previewWindow?.appearance = appearance
    }

    private func handleShortcut(_ action: ShortcutAction) {
        switch action {
        case .toggleApp:
            togglePopover()

        case .openChat:
            showPopover()
            NotificationCenter.default.post(name: Self.switchTabNotification, object: "chat")

        case .openCalendar:
            showPopover()
            NotificationCenter.default.post(name: Self.switchTabNotification, object: "calendar")

        case .openSettings:
            showPopover()
            NotificationCenter.default.post(name: Self.switchTabNotification, object: "settings")

        case .newEvent:
            showPopover()
            NotificationCenter.default.post(name: Self.switchTabNotification, object: "calendar")
            // Post additional notification for new event
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                NotificationCenter.default.post(name: Notification.Name("NewEventRequested"), object: nil)
            }

        case .newEmail:
            showPopover()
            NotificationCenter.default.post(name: Self.switchTabNotification, object: "email")

        case .refresh:
            NotificationCenter.default.post(name: Notification.Name("RefreshRequested"), object: nil)
        }
    }
}

// MARK: - Event Monitor for clicking outside popover
class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void

    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    deinit {
        stop()
    }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }

    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
