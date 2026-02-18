import SwiftUI
import Carbon

struct KeyboardShortcutsView: View {
    @StateObject private var shortcutService = KeyboardShortcutService.shared
    @State private var recordingShortcut: ShortcutAction?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Keyboard Shortcuts")
                        .font(.headline)
                    Text("Configure global hotkeys for quick access")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Reset to Defaults") {
                    shortcutService.resetToDefaults()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Divider()

            // Shortcuts list
            ForEach(shortcutService.shortcuts) { shortcut in
                ShortcutRow(
                    shortcut: shortcut,
                    isRecording: recordingShortcut == shortcut.action,
                    onStartRecording: {
                        recordingShortcut = shortcut.action
                        shortcutService.startRecording(for: shortcut.action)
                    },
                    onRecordKey: { keyCode, modifiers in
                        shortcutService.recordKey(keyCode: keyCode, modifiers: modifiers)
                        recordingShortcut = nil
                    },
                    onCancelRecording: {
                        shortcutService.stopRecording()
                        recordingShortcut = nil
                    }
                )
            }

            // Note
            Text("Click a shortcut to change it. Press your desired key combination.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .padding()
    }
}

struct ShortcutRow: View {
    let shortcut: KeyboardShortcut
    let isRecording: Bool
    let onStartRecording: () -> Void
    let onRecordKey: (UInt32, UInt32) -> Void
    let onCancelRecording: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: shortcut.action.icon)
                .frame(width: 20)
                .foregroundColor(.warmPrimary)

            Text(shortcut.action.displayName)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isRecording {
                KeyRecorderView(
                    onRecordKey: onRecordKey,
                    onCancel: onCancelRecording
                )
            } else {
                Button(action: onStartRecording) {
                    Text(shortcut.displayString)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

struct KeyRecorderView: View {
    let onRecordKey: (UInt32, UInt32) -> Void
    let onCancel: () -> Void

    @State private var currentModifiers: UInt32 = 0

    var body: some View {
        HStack(spacing: 8) {
            Text(modifiersString)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.warmPrimary)
                .frame(minWidth: 60)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.warmPrimary.opacity(0.1))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.warmPrimary, lineWidth: 1)
                )

            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
                handleKeyEvent(event)
                return nil
            }
        }
    }

    private var modifiersString: String {
        if currentModifiers == 0 {
            return "Press keys..."
        }

        var parts: [String] = []
        if currentModifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if currentModifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if currentModifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if currentModifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        return parts.isEmpty ? "Press keys..." : parts.joined()
    }

    private func handleKeyEvent(_ event: NSEvent) {
        if event.type == .flagsChanged {
            var mods: UInt32 = 0
            if event.modifierFlags.contains(.command) { mods |= UInt32(cmdKey) }
            if event.modifierFlags.contains(.shift) { mods |= UInt32(shiftKey) }
            if event.modifierFlags.contains(.option) { mods |= UInt32(optionKey) }
            if event.modifierFlags.contains(.control) { mods |= UInt32(controlKey) }
            currentModifiers = mods
        } else if event.type == .keyDown {
            // Record the key combination
            var mods: UInt32 = 0
            if event.modifierFlags.contains(.command) { mods |= UInt32(cmdKey) }
            if event.modifierFlags.contains(.shift) { mods |= UInt32(shiftKey) }
            if event.modifierFlags.contains(.option) { mods |= UInt32(optionKey) }
            if event.modifierFlags.contains(.control) { mods |= UInt32(controlKey) }

            // Require at least one modifier
            if mods != 0 {
                onRecordKey(UInt32(event.keyCode), mods)
            }
        }
    }
}

// MARK: - Settings Embedded View
struct KeyboardShortcutsSettingsView: View {
    @StateObject private var shortcutService = KeyboardShortcutService.shared
    @State private var recordingShortcut: ShortcutAction?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(shortcutService.shortcuts) { shortcut in
                HStack {
                    Image(systemName: shortcut.action.icon)
                        .frame(width: 20)
                        .foregroundColor(.warmPrimary)

                    Text(shortcut.action.displayName)
                        .font(.subheadline)

                    Spacer()

                    if recordingShortcut == shortcut.action {
                        Text("Press keys...")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.warmPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.warmPrimary.opacity(0.1))
                            .cornerRadius(4)

                        Button(action: { recordingShortcut = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: {
                            recordingShortcut = shortcut.action
                        }) {
                            Text(shortcut.displayString)
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Reset to Defaults") {
                    shortcutService.resetToDefaults()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.top, 4)
        }
        .onAppear {
            setupKeyMonitor()
        }
    }

    private func setupKeyMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let action = recordingShortcut else { return event }

            var mods: UInt32 = 0
            if event.modifierFlags.contains(.command) { mods |= UInt32(cmdKey) }
            if event.modifierFlags.contains(.shift) { mods |= UInt32(shiftKey) }
            if event.modifierFlags.contains(.option) { mods |= UInt32(optionKey) }
            if event.modifierFlags.contains(.control) { mods |= UInt32(controlKey) }

            if mods != 0 {
                let newShortcut = KeyboardShortcut(
                    action: action,
                    keyCode: UInt32(event.keyCode),
                    modifiers: mods
                )
                shortcutService.updateShortcut(newShortcut)
                recordingShortcut = nil
            }

            return nil
        }
    }
}

#Preview {
    KeyboardShortcutsView()
        .frame(width: 400)
}
