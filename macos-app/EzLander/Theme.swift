import SwiftUI
import Combine

// MARK: - Theme Mode
enum ThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    /// Posted when the theme changes so AppKit views (e.g. NSPopover) can update.
    static let themeDidChangeNotification = Notification.Name("ThemeDidChangeNotification")

    @Published var selectedMode: ThemeMode {
        didSet {
            UserDefaults.standard.set(selectedMode.rawValue, forKey: "theme_mode")
            applyAppearance()
        }
    }

    /// The resolved color scheme based on the selected mode, or nil for system default.
    var resolvedColorScheme: ColorScheme? {
        switch selectedMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// The resolved NSAppearance for the current mode, or nil for system default.
    var resolvedNSAppearance: NSAppearance? {
        switch selectedMode {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "theme_mode"),
           let mode = ThemeMode(rawValue: saved) {
            self.selectedMode = mode
        } else {
            self.selectedMode = .system
        }
        applyAppearance()
    }

    func applyAppearance() {
        DispatchQueue.main.async {
            let appearance = self.resolvedNSAppearance
            NSApp.appearance = appearance
            NotificationCenter.default.post(name: Self.themeDidChangeNotification, object: appearance)
        }
    }
}

// MARK: - Warm & Modern Color Theme
extension Color {
    // Primary coral — main interactive elements, buttons, selected states
    static let warmPrimary = Color(red: 1.0, green: 0.42, blue: 0.42)       // #FF6B6B

    // Accent amber — secondary highlights, gradients
    static let warmAccent = Color(red: 1.0, green: 0.66, blue: 0.30)        // #FFA94D

    // Highlight warm yellow — badges, special elements
    static let warmHighlight = Color(red: 1.0, green: 0.85, blue: 0.24)     // #FFD93D

    // Soft peach — subtle backgrounds, hover states
    static let warmSoft = Color(red: 1.0, green: 0.91, blue: 0.87)          // #FFE8DE

    // Gradient: coral to amber
    static let warmGradient = LinearGradient(
        colors: [warmPrimary, warmAccent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // User message bubble — warm coral
    static let userBubble = Color(red: 1.0, green: 0.42, blue: 0.42)        // #FF6B6B

    // Event indicator dot color
    static let eventDot = Color(red: 1.0, green: 0.55, blue: 0.36)          // #FF8C5C

    // Pro badge gold
    static let proBadge = Color(red: 1.0, green: 0.76, blue: 0.20)          // #FFC233

    // Initialize from hex string (e.g. "#FF6B6B" or "FF6B6B")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch hex.count {
        case 6: // RGB
            (r, g, b, a) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8: // RGBA
            (r, g, b, a) = (int >> 24 & 0xFF, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }
        self.init(
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
}

// MARK: - Warm Gradient Button Style
struct WarmGradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .font(.headline)
            .foregroundColor(.white)
            .background(
                LinearGradient(
                    colors: [Color.warmPrimary, Color.warmAccent],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

extension ButtonStyle where Self == WarmGradientButtonStyle {
    static var warmGradient: WarmGradientButtonStyle { WarmGradientButtonStyle() }
}
