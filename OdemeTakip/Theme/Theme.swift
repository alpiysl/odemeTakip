import SwiftUI

enum Theme {
    static let background = Color(hex: 0x0B0B0F)
    static let surface = Color(hex: 0x1C1C22)
    static let divider = Color(hex: 0x1F1F26)
    static let footer = Color(hex: 0x15151B)
    static let ring = Color(hex: 0x3A3A44)
    static let credit = Color(hex: 0x64D2FF)
    static let cash = Color(hex: 0xFFD60A)
    static let paid = Color(hex: 0x30D158)
    static let accent = Color(hex: 0xBF5AF2)
    static let gradientStart = Color(hex: 0x5E5CE6)
    static let secondaryText = Color.white.opacity(0.5)
    static let tertiaryText = Color.white.opacity(0.3)

    static let savingsStart = Color(hex: 0x0F9B8E)

    static var savingsGradient: LinearGradient {
        LinearGradient(colors: [savingsStart, paid], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var gradient: LinearGradient {
        LinearGradient(colors: [gradientStart, accent], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func kindColor(_ kind: PaymentKind) -> Color {
        kind == .credit ? credit : cash
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }
}
