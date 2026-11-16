import Foundation

/// `Settings.xcstrings`: başlık, Borç | Birikim anahtarı, ayarlar, net varlık satırı, ilk kurulum.
extension L10n {
    enum Settings {
        private static func s(_ key: String, _ args: CVarArg...) -> String {
            L10n.string(key, table: "Settings", args: args)
        }

        static var modeDebtTitle: String { s("settings.modeDebtTitle") }
        static var modeSavingsTitle: String { s("settings.modeSavingsTitle") }
        static var modeDebtShort: String { s("settings.modeDebtShort") }
        static var modeSavingsShort: String { s("settings.modeSavingsShort") }
        static var appTitle: String { s("settings.appTitle") }
        static var title: String { s("settings.title") }
        /// "Açılış ekranı: Borç Takip"
        static func landingToast(_ mode: String) -> String { s("settings.landingToast", mode) }
        /// "Görünüm: Koyu"
        static func appearanceToast(_ appearance: String) -> String { s("settings.appearanceToast", appearance) }
        static var landingTitle: String { s("settings.landingTitle") }
        static var landingFooter: String { s("settings.landingFooter") }
        static var appearanceTitle: String { s("settings.appearanceTitle") }
        static var appearanceFooter: String { s("settings.appearanceFooter") }
        static var appearanceDark: String { s("settings.appearanceDark") }
        static var appearanceLight: String { s("settings.appearanceLight") }
        static var sourceCurrencies: String { s("settings.sourceCurrencies") }
        static var sourceCurrenciesValue: String { s("settings.sourceCurrenciesValue") }
        static var sourceGold: String { s("settings.sourceGold") }
        static var sourceGoldValue: String { s("settings.sourceGoldValue") }
        static var sourcesTitle: String { s("settings.sourcesTitle") }
        static var sourcesFooter: String { s("settings.sourcesFooter") }
        static var netWorth: String { s("settings.netWorth") }
        static var welcome: String { s("settings.welcome") }
        static var welcomeMessage: String { s("settings.welcomeMessage") }
        static var onboardingDebtDetail: String { s("settings.onboardingDebtDetail") }
        static var onboardingSavingsDetail: String { s("settings.onboardingSavingsDetail") }
        static var continueButton: String { s("settings.continue") }
    }
}
