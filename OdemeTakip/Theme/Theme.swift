import SwiftUI
import UIKit

enum Theme {
    static let background = Color(light: 0xF2F2F7, dark: 0x0B0B0F)
    static let surface = Color(light: 0xFFFFFF, dark: 0x1C1C22)
    static let divider = Color(light: 0xE2E2E8, dark: 0x1F1F26)
    static let footer = Color(light: 0xFFFFFF, dark: 0x15151B)
    static let footerBorder = Color(light: 0xDCDCE2, dark: 0x24242C)
    static let ring = Color(light: 0xC7C7CC, dark: 0x3A3A44)
    static let credit = Color(light: 0x0A7EC2, dark: 0x64D2FF)
    static let cash = Color(light: 0xB98900, dark: 0xFFD60A)
    static let paid = Color(light: 0x1F9D45, dark: 0x30D158)
    static let negative = Color(light: 0xD70015, dark: 0xFF6961)
    static let accent = Color(light: 0xA444D8, dark: 0xBF5AF2)
    static let gradientStart = Color(hex: 0x5E5CE6)
    static let gradientEnd = Color(hex: 0xBF5AF2)
    static let primaryText = Color(light: 0x000000, dark: 0xFFFFFF)
    static let secondaryText = Color(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.55, darkAlpha: 0.5)
    static let tertiaryText = Color(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.3, darkAlpha: 0.3)
    /// Seçilmemiş segment metni.
    static let unselectedText = Color(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.55, darkAlpha: 0.55)
    /// İlerleme çubuğu zemini.
    static let track = Color(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.08, darkAlpha: 0.08)
    static let toastBackground = Color(light: 0xFFFFFF, dark: 0x28282F)
    static let toastBorder = Color(light: 0xDCDCE2, dark: 0x33333D)
    static let cardBorder = Color(light: 0xDCDCE2, dark: 0x2A2A33)

    static let savingsStart = Color(hex: 0x0F9B8E)
    static let savingsEnd = Color(hex: 0x30D158)

    /// Kartlar beyaz yazılı; renkler her iki temada aynı kalır.
    static var savingsGradient: LinearGradient {
        LinearGradient(colors: [savingsStart, savingsEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var gradient: LinearGradient {
        LinearGradient(colors: [gradientStart, gradientEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func kindColor(_ kind: PaymentKind) -> Color {
        kind == .credit ? credit : cash
    }
}

/// Görünüm tercihi (Ayarlar). Varsayılan koyu.
enum AppAppearance: String, CaseIterable, Identifiable {
    case dark
    case light

    static let storageKey = "appearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: L10n.Settings.appearanceDark
        case .light: L10n.Settings.appearanceLight
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .dark: .dark
        case .light: .light
        }
    }
}

extension View {
    /// Kayıtlı görünüm tercihini uygular (pencere ve sheet'ler).
    func appColorScheme() -> some View {
        modifier(AppColorSchemeModifier())
    }
}

private struct AppColorSchemeModifier: ViewModifier {
    @AppStorage(AppAppearance.storageKey) private var raw = AppAppearance.dark.rawValue

    func body(content: Content) -> some View {
        content.preferredColorScheme((AppAppearance(rawValue: raw) ?? .dark).colorScheme)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }

    /// Açık / koyu temaya göre değişen renk.
    init(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
    }
}
