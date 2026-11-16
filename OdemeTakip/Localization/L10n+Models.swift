import Foundation

/// `Models.xcstrings`: kayıt türleri, para birimleri, altın birimleri, kur kaynağı.
extension L10n {
    enum Models {
        private static func s(_ key: String, _ args: CVarArg...) -> String {
            L10n.string(key, table: "Models", args: args)
        }

        static var kindCredit: String { s("models.kindCredit") }
        static var kindCash: String { s("models.kindCash") }
        static var kindReceivable: String { s("models.kindReceivable") }

        static var unitGram: String { s("models.unitGram") }
        static var unitCeyrek: String { s("models.unitCeyrek") }
        static var unitYarim: String { s("models.unitYarim") }
        static var unitTam: String { s("models.unitTam") }
        static var unitResat: String { s("models.unitResat") }

        static var currencyTRY: String { s("models.currencyTRY") }
        static var currencyUSD: String { s("models.currencyUSD") }
        static var currencyEUR: String { s("models.currencyEUR") }
        static var currencyGram: String { s("models.currencyGram") }
        static var currencyCeyrek: String { s("models.currencyCeyrek") }
        static var currencyYarim: String { s("models.currencyYarim") }
        static var currencyTam: String { s("models.currencyTam") }
        static var currencyResat: String { s("models.currencyResat") }

        /// "TCMB 19 Eki"
        static func rateSource(_ date: String) -> String { s("models.rateSource", date) }
    }
}
