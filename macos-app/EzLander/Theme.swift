import SwiftUI

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
