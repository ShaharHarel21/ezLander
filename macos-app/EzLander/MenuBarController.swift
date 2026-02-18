import SwiftUI
import AppKit

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: EventMonitor?
    private let shortcutService = KeyboardShortcutService.shared
    private var statusMenu: NSMenu!

    // Notification for tab switching
    static let switchTabNotification = Notification.Name("SwitchTabNotification")

    override init() {
        super.init()
        setupStatusItem()
        setupPopover()
        setupMenu()
        setupEventMonitor()
        setupKeyboardShortcuts()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.image?.isTemplate = true
            button.action = #selector(handleClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
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
        popover.behavior = .transient
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
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            eventMonitor?.start()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        eventMonitor?.stop()
    }

    private func setupKeyboardShortcuts() {
        shortcutService.onShortcutTriggered = { [weak self] action in
            DispatchQueue.main.async {
                self?.handleShortcut(action)
            }
        }
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
