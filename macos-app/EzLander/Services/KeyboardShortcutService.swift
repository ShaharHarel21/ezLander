import Foundation
import Carbon
import AppKit

// MARK: - Shortcut Definition
struct KeyboardShortcut: Codable, Identifiable, Equatable {
    var id: String { action.rawValue }
    let action: ShortcutAction
    var keyCode: UInt32
    var modifiers: UInt32

    var displayString: String {
        var parts: [String] = []

        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }

        if let keyString = KeyboardShortcutService.keyCodeToString(keyCode) {
            parts.append(keyString)
        }

        return parts.joined()
    }

    static func == (lhs: KeyboardShortcut, rhs: KeyboardShortcut) -> Bool {
        lhs.action == rhs.action && lhs.keyCode == rhs.keyCode && lhs.modifiers == rhs.modifiers
    }
}

enum ShortcutAction: String, Codable, CaseIterable {
    case toggleApp = "toggle_app"
    case newEvent = "new_event"
    case newEmail = "new_email"
    case openChat = "open_chat"
    case openCalendar = "open_calendar"
    case openSettings = "open_settings"
    case refresh = "refresh"

    var displayName: String {
        switch self {
        case .toggleApp: return "Toggle ezLander"
        case .newEvent: return "New Calendar Event"
        case .newEmail: return "New Email"
        case .openChat: return "Open Chat"
        case .openCalendar: return "Open Calendar"
        case .openSettings: return "Open Settings"
        case .refresh: return "Refresh Data"
        }
    }

    var icon: String {
        switch self {
        case .toggleApp: return "menubar.rectangle"
        case .newEvent: return "calendar.badge.plus"
        case .newEmail: return "envelope.badge.plus"
        case .openChat: return "bubble.left.and.bubble.right"
        case .openCalendar: return "calendar"
        case .openSettings: return "gearshape"
        case .refresh: return "arrow.clockwise"
        }
    }
}

// MARK: - Keyboard Shortcut Service
class KeyboardShortcutService: ObservableObject {
    static let shared = KeyboardShortcutService()

    @Published var shortcuts: [KeyboardShortcut] = []
    @Published var isRecording: Bool = false
    @Published var recordingAction: ShortcutAction?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var hotKeyRefs: [EventHotKeyRef?] = []

    // Callback for when a shortcut is triggered
    var onShortcutTriggered: ((ShortcutAction) -> Void)?

    private init() {
        loadShortcuts()
        registerHotKeys()
    }

    // MARK: - Default Shortcuts
    static var defaultShortcuts: [KeyboardShortcut] {
        [
            KeyboardShortcut(action: .toggleApp, keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey | shiftKey)),
            KeyboardShortcut(action: .newEvent, keyCode: UInt32(kVK_ANSI_E), modifiers: UInt32(cmdKey | shiftKey)),
            KeyboardShortcut(action: .newEmail, keyCode: UInt32(kVK_ANSI_M), modifiers: UInt32(cmdKey | shiftKey)),
            KeyboardShortcut(action: .openChat, keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(cmdKey | shiftKey)),
            KeyboardShortcut(action: .openCalendar, keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(cmdKey | shiftKey)),
            KeyboardShortcut(action: .refresh, keyCode: UInt32(kVK_ANSI_R), modifiers: UInt32(cmdKey | shiftKey))
        ]
    }

    // MARK: - Load/Save
    func loadShortcuts() {
        if let data = UserDefaults.standard.data(forKey: "keyboard_shortcuts"),
           let decoded = try? JSONDecoder().decode([KeyboardShortcut].self, from: data) {
            shortcuts = decoded
        } else {
            shortcuts = Self.defaultShortcuts
        }
    }

    func saveShortcuts() {
        if let encoded = try? JSONEncoder().encode(shortcuts) {
            UserDefaults.standard.set(encoded, forKey: "keyboard_shortcuts")
        }
        registerHotKeys()
    }

    func resetToDefaults() {
        shortcuts = Self.defaultShortcuts
        saveShortcuts()
    }

    func updateShortcut(_ shortcut: KeyboardShortcut) {
        if let index = shortcuts.firstIndex(where: { $0.action == shortcut.action }) {
            shortcuts[index] = shortcut
            saveShortcuts()
        }
    }

    // MARK: - Hot Key Registration
    func registerHotKeys() {
        // Unregister existing hot keys
        for ref in hotKeyRefs {
            if let ref = ref {
                UnregisterEventHotKey(ref)
            }
        }
        hotKeyRefs.removeAll()

        // Register new hot keys
        for (index, shortcut) in shortcuts.enumerated() {
            var hotKeyRef: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: OSType(0x455A4C44), id: UInt32(index)) // "EZLD"

            let status = RegisterEventHotKey(
                shortcut.keyCode,
                shortcut.modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )

            if status == noErr {
                hotKeyRefs.append(hotKeyRef)
            } else {
                print("Failed to register hotkey for \(shortcut.action): \(status)")
                hotKeyRefs.append(nil)
            }
        }

        // Install event handler
        installEventHandler()
    }

    private var eventHandlerRef: EventHandlerRef?

    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let service = Unmanaged<KeyboardShortcutService>.fromOpaque(userData).takeUnretainedValue()

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            if status == noErr {
                let index = Int(hotKeyID.id)
                if index < service.shortcuts.count {
                    DispatchQueue.main.async {
                        service.onShortcutTriggered?(service.shortcuts[index].action)
                    }
                }
            }

            return noErr
        }

        let userDataPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            userDataPtr,
            &eventHandlerRef
        )
    }

    // MARK: - Key Recording
    func startRecording(for action: ShortcutAction) {
        isRecording = true
        recordingAction = action
    }

    func stopRecording() {
        isRecording = false
        recordingAction = nil
    }

    func recordKey(keyCode: UInt32, modifiers: UInt32) {
        guard isRecording, let action = recordingAction else { return }

        let newShortcut = KeyboardShortcut(action: action, keyCode: keyCode, modifiers: modifiers)
        updateShortcut(newShortcut)

        stopRecording()
    }

    // MARK: - Key Code Conversion
    static func keyCodeToString(_ keyCode: UInt32) -> String? {
        let keyCodeMap: [UInt32: String] = [
            UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C",
            UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
            UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I",
            UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
            UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
            UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
            UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U",
            UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
            UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
            UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2",
            UInt32(kVK_ANSI_3): "3", UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
            UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7", UInt32(kVK_ANSI_8): "8",
            UInt32(kVK_ANSI_9): "9",
            UInt32(kVK_Space): "Space",
            UInt32(kVK_Return): "↩",
            UInt32(kVK_Tab): "⇥",
            UInt32(kVK_Delete): "⌫",
            UInt32(kVK_Escape): "⎋",
            UInt32(kVK_LeftArrow): "←",
            UInt32(kVK_RightArrow): "→",
            UInt32(kVK_UpArrow): "↑",
            UInt32(kVK_DownArrow): "↓",
            UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2", UInt32(kVK_F3): "F3",
            UInt32(kVK_F4): "F4", UInt32(kVK_F5): "F5", UInt32(kVK_F6): "F6",
            UInt32(kVK_F7): "F7", UInt32(kVK_F8): "F8", UInt32(kVK_F9): "F9",
            UInt32(kVK_F10): "F10", UInt32(kVK_F11): "F11", UInt32(kVK_F12): "F12"
        ]
        return keyCodeMap[keyCode]
    }
}
