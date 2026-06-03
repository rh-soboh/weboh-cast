import SwiftUI

extension Color {
    static let wcOrange = Color(red: 1.0, green: 0.427, blue: 0.0) // #FF6D00
    static let wcBackground = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1) : .systemBackground
    })
    static let wcSurface = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.11, green: 0.11, blue: 0.14, alpha: 1) : .secondarySystemBackground
    })
    static let wcSurfaceElevated = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1) : .tertiarySystemBackground
    })
    static let wcText = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? .white : .label
    })
    static let wcTextSecondary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(white: 0.6, alpha: 1) : .secondaryLabel
    })
}

extension View {
    func wcCard() -> some View {
        self
            .background(Color.wcSurface)
            .cornerRadius(12)
    }
}
