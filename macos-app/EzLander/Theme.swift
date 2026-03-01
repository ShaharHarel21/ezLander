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

// MARK: - Appearance Mode (legacy compat)
enum AppearanceMode: String {
    case light, dark, system

    func apply() {
        switch self {
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system: NSApp.appearance = nil
        }
    }
}

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    static let themeDidChangeNotification = Notification.Name("ThemeDidChangeNotification")

    @Published var selectedMode: ThemeMode {
        didSet {
            UserDefaults.standard.set(selectedMode.rawValue, forKey: "theme_mode")
            applyAppearance()
        }
    }

    var resolvedColorScheme: ColorScheme? {
        switch selectedMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

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

// MARK: - 2026 Design System
extension Color {
    // Primary — refined indigo-violet instead of coral (more premium, less aggressive)
    static let warmPrimary = Color(red: 0.38, green: 0.35, blue: 0.96)      // #615AF5 — Electric indigo

    // Accent — soft violet for gradients
    static let warmAccent = Color(red: 0.65, green: 0.45, blue: 1.0)        // #A673FF — Soft purple

    // Highlight — luminous cyan for special elements
    static let warmHighlight = Color(red: 0.25, green: 0.88, blue: 0.82)    // #40E0D0 — Teal

    // Soft background tint
    static let warmSoft = Color(red: 0.95, green: 0.94, blue: 1.0)          // #F2F0FF — Lavender mist

    // Gradient: indigo to purple
    static let warmGradient = LinearGradient(
        colors: [warmPrimary, warmAccent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // User message bubble
    static let userBubble = Color(red: 0.38, green: 0.35, blue: 0.96)       // #615AF5

    // Event indicator dot
    static let eventDot = Color(red: 0.65, green: 0.45, blue: 1.0)          // #A673FF

    // Pro badge
    static let proBadge = Color(red: 1.0, green: 0.76, blue: 0.20)          // #FFC233 — Gold

    // Surface colors for cards/panels
    static let surfacePrimary = Color(NSColor.windowBackgroundColor)
    static let surfaceElevated = Color(NSColor.controlBackgroundColor)

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch hex.count {
        case 6:
            (r, g, b, a) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8:
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

// MARK: - Glass Effect Modifier
struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
            )
    }
}

extension View {
    func glassBackground(cornerRadius: CGFloat = 12) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius))
    }
}

// MARK: - Modern Card Style
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.surfaceElevated)
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

// MARK: - Warm Gradient Button Style
struct WarmGradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .font(.system(.body, design: .rounded, weight: .semibold))
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.warmPrimary, Color.warmAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color.warmPrimary.opacity(0.3), radius: 8, y: 4)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == WarmGradientButtonStyle {
    static var warmGradient: WarmGradientButtonStyle { WarmGradientButtonStyle() }
}
