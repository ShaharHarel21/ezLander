import SwiftUI

// MARK: - Blue & Purple Modern Theme (matches website branding)
extension Color {
    // Primary blue — main interactive elements, buttons, selected states
    static let warmPrimary = Color(red: 0.047, green: 0.549, blue: 0.902)       // #0C8CE6

    // Accent purple — secondary highlights, gradients
    static let warmAccent = Color(red: 0.851, green: 0.275, blue: 0.937)        // #D946EF

    // Highlight light blue — badges, special elements
    static let warmHighlight = Color(red: 0.212, green: 0.667, blue: 0.961)     // #36AAF5

    // Soft blue tint — subtle backgrounds, hover states
    static let warmSoft = Color(red: 0.878, green: 0.937, blue: 0.996)          // #E0EFFE

    // Gradient: blue to purple
    static let warmGradient = LinearGradient(
        colors: [warmPrimary, warmAccent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // User message bubble — primary blue
    static let userBubble = Color(red: 0.047, green: 0.549, blue: 0.902)        // #0C8CE6

    // Event indicator dot color
    static let eventDot = Color(red: 0.486, green: 0.549, blue: 0.984)          // #7C8CFB

    // Pro badge gold
    static let proBadge = Color(red: 1.0, green: 0.76, blue: 0.20)             // #FFC233

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

// MARK: - Gradient Button Style
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
