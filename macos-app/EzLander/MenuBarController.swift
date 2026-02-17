import SwiftUI
import AppKit

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: EventMonitor?
    private let shortcutService = KeyboardShortcutService.shared

    // Notification for tab switching
    static let switchTabNotification = Notification.Name("SwitchTabNotification")

    override init() {
        super.init()
        setupStatusItem()
        setupPopover()
        setupEventMonitor()
        setupKeyboardShortcuts()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "ezLander")
            button.action = #selector(togglePopover)
            button.target = self
        }
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

    private func showPopover() {
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
