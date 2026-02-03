import SwiftUI

enum Theme {
    // Night palette: black / white with subtle grays.
    static let black = Color.black
    static let white = Color.white

    static let background = Color(red: 0.02, green: 0.02, blue: 0.025)
    static let surface = Color(red: 0.07, green: 0.07, blue: 0.08)
    static let border = white.opacity(0.18)
    static let accent = white
    static let textPrimary = white
    static let textSecondary = white.opacity(0.7)
    static let error = white
}

struct CyberpunkCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(Theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

extension View {
    func cyberpunkCard() -> some View { modifier(CyberpunkCard()) }
}
