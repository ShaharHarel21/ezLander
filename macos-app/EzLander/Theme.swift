import SwiftUI

// MARK: - Eden-Inspired Green Color Theme
extension Color {
    // Primary green — main interactive elements, buttons, selected states
    static let warmPrimary = Color(red: 0.18, green: 0.49, blue: 0.32)      // #2E7D52

    // Accent green — secondary highlights, gradients
    static let warmAccent = Color(red: 0.35, green: 0.71, blue: 0.49)       // #5AB47D

    // Highlight mint — badges, special elements
    static let warmHighlight = Color(red: 0.66, green: 0.90, blue: 0.81)    // #A8E6CF

    // Soft sage — subtle backgrounds, hover states
    static let warmSoft = Color(red: 0.91, green: 0.96, blue: 0.91)         // #E8F5E9

    // Gradient: deep green to lighter green
    static let warmGradient = LinearGradient(
        colors: [warmPrimary, warmAccent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // User message bubble — eden green
    static let userBubble = Color(red: 0.18, green: 0.49, blue: 0.32)       // #2E7D52

    // Event indicator dot color
    static let eventDot = Color(red: 0.35, green: 0.71, blue: 0.49)         // #5AB47D

    // Pro badge mint
    static let proBadge = Color(red: 0.66, green: 0.90, blue: 0.81)         // #A8E6CF

    // Initialize from hex string (e.g. "#FF6B6B" or "FF6B6B")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch hex.count {
        case 6: // RGB
            (r, g, b, a) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8: // ARGB
            (r, g, b, a) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF, int >> 24 & 0xFF)
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
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [Color.warmPrimary, Color.warmAccent],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

extension ButtonStyle where Self == WarmGradientButtonStyle {
    static var warmGradient: WarmGradientButtonStyle { WarmGradientButtonStyle() }
}
