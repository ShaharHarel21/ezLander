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

// MARK: - Liquid Glass Tokens
extension Color {
    static let glassCoralTint    = Color.warmPrimary.opacity(0.08)
    static let glassAmberTint    = Color.warmAccent.opacity(0.07)
    static let glassPeachTint    = Color.warmSoft.opacity(0.12)
    static let glassSpecular     = Color.white.opacity(0.18)
    static let glassBorder       = Color.primary.opacity(0.08)
    static let glassHover        = Color.warmPrimary.opacity(0.06)
    static let glassPressed      = Color.warmPrimary.opacity(0.14)
    static let glassSeparator    = Color.primary.opacity(0.10)
}

// MARK: - Adaptive Edge Color
/// Returns a border/edge color that works in both light and dark mode.
/// In dark mode, uses white at the given opacity for glass highlights.
/// In light mode, uses black at reduced opacity so borders don't appear as white lines.
struct AdaptiveEdge: View {
    let opacity: Double
    @Environment(\.colorScheme) var colorScheme

    var color: Color {
        colorScheme == .dark
            ? Color.white.opacity(opacity)
            : Color.black.opacity(opacity * 0.35)
    }

    var body: some View { EmptyView() }
}

/// A helper that vends the adaptive border color for a given base opacity.
extension View {
    func adaptiveBorder(cornerRadius: CGFloat, opacity: Double = 0.12, lineWidth: CGFloat = 0.75) -> some View {
        modifier(AdaptiveBorderModifier(cornerRadius: cornerRadius, opacity: opacity, lineWidth: lineWidth))
    }
}

private struct AdaptiveBorderModifier: ViewModifier {
    let cornerRadius: CGFloat
    let opacity: Double
    let lineWidth: CGFloat
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(borderColor, lineWidth: lineWidth)
        )
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(opacity)
            : Color.black.opacity(opacity * 0.35)
    }
}

// MARK: - Glass Infrastructure

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct GlassPanelBackground: View {
    var cornerRadius: CGFloat = 12
    var tint: Color = .clear
    var thickness: GlassThickness = .regular
    @Environment(\.colorScheme) var colorScheme

    enum GlassThickness { case thin, regular, thick }

    private var tintOpacity: Double { colorScheme == .dark ? 1.0 : 0.7 }
    private var edgeOpacity: Double { colorScheme == .dark ? 0.25 : 0.45 }

    var body: some View {
        if #available(macOS 26, *) {
            nativeGlass
        } else {
            fallbackGlass
        }
    }

    @available(macOS 26, *)
    private var nativeGlass: some View {
        ZStack {
            if tint != .clear {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(tint.opacity(tintOpacity))
            }
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var specularColor: Color { colorScheme == .dark ? .white : .black }
    private var specularStrength: Double { colorScheme == .dark ? 0.18 : 0.04 }

    private var fallbackGlass: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius).fill(.ultraThinMaterial)
            if tint != .clear {
                RoundedRectangle(cornerRadius: cornerRadius).fill(tint.opacity(tintOpacity))
            }
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(RadialGradient(
                    colors: [specularColor.opacity(specularStrength), specularColor.opacity(0)],
                    center: UnitPoint(x: 0.2, y: 0.12),
                    startRadius: 0, endRadius: 140
                ))
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            borderEdgeColor(edgeOpacity),
                            borderEdgeColor(edgeOpacity * 0.22),
                            borderEdgeColor(edgeOpacity * 0.12),
                            borderEdgeColor(edgeOpacity * 0.40)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        }
    }

    private func borderEdgeColor(_ opacity: Double) -> Color {
        colorScheme == .dark
            ? .white.opacity(opacity)
            : .black.opacity(opacity * 0.3)
    }
}

struct LiquidShadow: ViewModifier {
    var radius: CGFloat = 12
    var opacity: Double = 0.12
    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(opacity), radius: radius, x: 0, y: 4)
            .shadow(color: .black.opacity(opacity * 0.6), radius: 2, x: 0, y: 1)
    }
}

struct GlassCard: ViewModifier {
    var tint: Color = .glassCoralTint
    var cornerRadius: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .background(GlassPanelBackground(cornerRadius: cornerRadius, tint: tint))
            .modifier(LiquidShadow())
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.colorScheme) var colorScheme

    private var shimmerColor: Color {
        colorScheme == .dark ? .white.opacity(0.18) : .black.opacity(0.06)
    }

    func body(content: Content) -> some View {
        content.overlay(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: max(0, phase - 0.3)),
                    .init(color: shimmerColor, location: max(0, min(1, phase))),
                    .init(color: .clear, location: min(1, phase + 0.3))
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { phase = 2 }
            }
        )
    }
}

struct LiquidPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.spring(response: 0.20, dampingFraction: 0.50), value: configuration.isPressed)
    }
}

extension View {
    func glassCard(tint: Color = .glassCoralTint, cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassCard(tint: tint, cornerRadius: cornerRadius))
    }
    func liquidShadow(radius: CGFloat = 12, opacity: Double = 0.12) -> some View {
        modifier(LiquidShadow(radius: radius, opacity: opacity))
    }
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Warm Gradient Button Style
struct WarmGradientButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [Color.warmPrimary, Color.warmAccent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    LinearGradient(
                        colors: [.white.opacity(0.20), .white.opacity(0.05), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                }
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.warmPrimary.opacity(isHovered ? 0.40 : 0.28), radius: isHovered ? 14 : 10, x: 0, y: 3)
            .brightness(isHovered ? 0.05 : 0)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onHover { hovering in isHovered = hovering }
    }
}

extension ButtonStyle where Self == WarmGradientButtonStyle {
    static var warmGradient: WarmGradientButtonStyle { WarmGradientButtonStyle() }
}
