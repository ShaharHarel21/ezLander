import SwiftUI
import AppKit

// MARK: - Menu Bar Icon Options
enum MenuBarIconOption: String, CaseIterable, Identifiable {
    case ezLander = "ezlander"
    case starFill = "star.fill"
    case sparkle = "sparkle"
    case boltFill = "bolt.fill"
    case wandAndStars = "wand.and.stars"
    case paperplaneFill = "paperplane.fill"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ezLander: return "ezLander"
        case .starFill: return "Star"
        case .sparkle: return "Sparkle"
        case .boltFill: return "Bolt"
        case .wandAndStars: return "Wand"
        case .paperplaneFill: return "Plane"
        }
    }

    /// SF Symbol name used for the settings picker preview
    var displayIcon: String {
        self == .ezLander ? "star.circle" : rawValue
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
    static let menuBarIconChangedNotification = Notification.Name("MenuBarIconChanged")

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
            name: Self.menuBarIconChangedNotification,
            object: nil
        )
    }

    private func updateMenuBarIcon(button: NSStatusBarButton) {
        let iconName = UserDefaults.standard.string(forKey: "menu_bar_icon") ?? MenuBarIconOption.ezLander.rawValue

        if iconName == MenuBarIconOption.ezLander.rawValue {
            // Load custom icon from asset catalog
            if let image = NSImage(named: "MenuBarIcon") {
                image.isTemplate = true
                image.size = NSSize(width: 18, height: 18)
                button.image = image
            }
        } else {
            // Load SF Symbol for other options
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "ezLander")?.withSymbolConfiguration(config)
            image?.isTemplate = true
            button.image = image
        }
    }

    @objc private func menuBarIconChanged() {
        if let button = statusItem.button {
            updateMenuBarIcon(button: button)
        }
    }

    private func setupMenu() {
        statusMenu = NSMenu()
        rebuildMenu()
    }

    private func rebuildMenu() {
        statusMenu.removeAllItems()

        // ── Quick Actions ──
        let quickHeader = NSMenuItem(title: "Quick Actions", action: nil, keyEquivalent: "")
        quickHeader.isEnabled = false
        statusMenu.addItem(quickHeader)

        let newChatItem = NSMenuItem(title: "New Chat", action: #selector(openChat), keyEquivalent: "")
        newChatItem.target = self
        newChatItem.image = NSImage(systemSymbolName: "bubble.left.fill", accessibilityDescription: nil)
        statusMenu.addItem(newChatItem)

        let newEmailItem = NSMenuItem(title: "Compose Email", action: #selector(openEmail), keyEquivalent: "")
        newEmailItem.target = self
        newEmailItem.image = NSImage(systemSymbolName: "envelope.fill", accessibilityDescription: nil)
        statusMenu.addItem(newEmailItem)

        let newEventItem = NSMenuItem(title: "New Event", action: #selector(openNewEvent), keyEquivalent: "")
        newEventItem.target = self
        newEventItem.image = NSImage(systemSymbolName: "calendar.badge.plus", accessibilityDescription: nil)
        statusMenu.addItem(newEventItem)

        statusMenu.addItem(NSMenuItem.separator())

        // ── Navigation ──
        let navHeader = NSMenuItem(title: "Navigation", action: nil, keyEquivalent: "")
        navHeader.isEnabled = false
        statusMenu.addItem(navHeader)

        let chatItem = NSMenuItem(title: "Open Chat", action: #selector(openChat), keyEquivalent: "1")
        chatItem.target = self
        chatItem.image = NSImage(systemSymbolName: "bubble.left.and.bubble.right.fill", accessibilityDescription: nil)
        statusMenu.addItem(chatItem)

        let calendarItem = NSMenuItem(title: "Open Calendar", action: #selector(openCalendar), keyEquivalent: "2")
        calendarItem.target = self
        calendarItem.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: nil)
        statusMenu.addItem(calendarItem)

        let emailItem = NSMenuItem(title: "Open Email", action: #selector(openEmail), keyEquivalent: "3")
        emailItem.target = self
        emailItem.image = NSImage(systemSymbolName: "envelope.fill", accessibilityDescription: nil)
        statusMenu.addItem(emailItem)

        let settingsItem = NSMenuItem(title: "Open Settings", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: nil)
        statusMenu.addItem(settingsItem)

        statusMenu.addItem(NSMenuItem.separator())

        // ── Tools ──
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshContent), keyEquivalent: "r")
        refreshItem.target = self
        refreshItem.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)
        statusMenu.addItem(refreshItem)

        // Theme submenu
        let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        themeItem.image = NSImage(systemSymbolName: "paintbrush.fill", accessibilityDescription: nil)
        let themeSubmenu = NSMenu()
        let currentMode = ThemeManager.shared.selectedMode
        for mode in ThemeMode.allCases {
            let modeItem = NSMenuItem(title: mode.label, action: #selector(setThemeMode(_:)), keyEquivalent: "")
            modeItem.target = self
            modeItem.representedObject = mode.rawValue
            modeItem.image = NSImage(systemSymbolName: mode.icon, accessibilityDescription: nil)
            modeItem.state = (mode == currentMode) ? .on : .off
            themeSubmenu.addItem(modeItem)
        }
        themeItem.submenu = themeSubmenu
        statusMenu.addItem(themeItem)

        statusMenu.addItem(NSMenuItem.separator())

        // ── Account ──
        let sub = SubscriptionService.shared
        let statusLabel: String
        if sub.isSubscribed {
            let planText = sub.plan.isEmpty ? "Active" : sub.plan.capitalized
            statusLabel = "Pro — \(planText)"
        } else {
            statusLabel = "Free — Not Subscribed"
        }
        let accountItem = NSMenuItem(title: statusLabel, action: nil, keyEquivalent: "")
        accountItem.isEnabled = false
        accountItem.image = NSImage(systemSymbolName: sub.isSubscribed ? "crown.fill" : "person.crop.circle", accessibilityDescription: nil)
        statusMenu.addItem(accountItem)

        let manageSubItem = NSMenuItem(
            title: sub.isSubscribed ? "Billing & Plans..." : "Subscribe...",
            action: #selector(manageSubscription),
            keyEquivalent: ""
        )
        manageSubItem.target = self
        manageSubItem.image = NSImage(systemSymbolName: "creditcard.fill", accessibilityDescription: nil)
        statusMenu.addItem(manageSubItem)

        statusMenu.addItem(NSMenuItem.separator())

        // ── App ──
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let versionItem = NSMenuItem(title: "ezLander v\(version)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        statusMenu.addItem(versionItem)

        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        updateItem.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: nil)
        statusMenu.addItem(updateItem)

        statusMenu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit ezLander", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        statusMenu.addItem(quitItem)
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Right click - rebuild and show menu (so dynamic items are current)
            rebuildMenu()
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

    @objc private func openChat() {
        showPopover()
        NotificationCenter.default.post(name: Self.switchTabNotification, object: "chat")
    }

    @objc private func openCalendar() {
        showPopover()
        NotificationCenter.default.post(name: Self.switchTabNotification, object: "calendar")
    }

    @objc private func openEmail() {
        showPopover()
        NotificationCenter.default.post(name: Self.switchTabNotification, object: "email")
    }

    @objc private func openSettings() {
        showPopover()
        NotificationCenter.default.post(name: Self.switchTabNotification, object: "settings")
    }

    @objc private func openNewEvent() {
        showPopover()
        NotificationCenter.default.post(name: Self.switchTabNotification, object: "calendar")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NotificationCenter.default.post(name: Notification.Name("NewEventRequested"), object: nil)
        }
    }

    @objc private func refreshContent() {
        NotificationCenter.default.post(name: Notification.Name("RefreshRequested"), object: nil)
    }

    @objc private func setThemeMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = ThemeMode(rawValue: rawValue) else { return }
        ThemeManager.shared.selectedMode = mode
    }

    @objc private func manageSubscription() {
        SubscriptionService.shared.openPurchasePage()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 420, height: 520)
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
            // Reset to the default Chat (AI Agent) tab each time
            NotificationCenter.default.post(name: Self.switchTabNotification, object: "chat")
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            eventMonitor?.start()
        }
    }

    func closePopover() {
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
        hostingController.preferredContentSize = NSSize(width: 420, height: 520)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.setContentSize(NSSize(width: 420, height: 520))
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
