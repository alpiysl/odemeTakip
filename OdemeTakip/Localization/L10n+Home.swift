import Foundation

/// `Home.xcstrings`: borç ana sayfası, özet kartı, kur şeridi, liste satırları.
extension L10n {
    enum Home {
        private static func s(_ key: String, _ args: CVarArg...) -> String {
            L10n.string(key, table: "Home", args: args)
        }

        static var storeUnavailable: String { s("home.storeUnavailable") }
        static var notificationsOff: String { s("home.notificationsOff") }
        static var newPayment: String { s("home.newPayment") }
        static var markThisMonthPaid: String { s("home.markThisMonthPaid") }
        static var markThisMonthUnpaid: String { s("home.markThisMonthUnpaid") }
        static var addPayment: String { s("home.addPayment") }
        static var emptyTitle: String { s("home.emptyTitle") }
        static var emptyMessage: String { s("home.emptyMessage") }
        /// "13/36"
        static func installmentProgress(_ paid: Int, _ total: Int) -> String { s("home.installmentProgress", paid, total) }
        /// "₺15.000/ay · Sıradaki Eki 2026"
        static func rowCreditNext(_ monthly: String, _ next: String) -> String { s("home.rowCreditNext", monthly, next) }
        /// "36/36 taksit · ₺15.000/ay"
        static func rowCredit(_ paid: Int, _ total: Int, _ monthly: String) -> String { s("home.rowCredit", paid, total, monthly) }
        static func rowCash(_ paid: String) -> String { s("home.rowCash", paid) }
        static func rowReceivable(_ collected: String) -> String { s("home.rowReceivable", collected) }
        static var rateUSD: String { s("home.rateUSD") }
        static var rateEUR: String { s("home.rateEUR") }
        static var rateGram: String { s("home.rateGram") }
        static var rateCeyrek: String { s("home.rateCeyrek") }
        static var rateYarim: String { s("home.rateYarim") }
        static var rateTam: String { s("home.rateTam") }
        static var rateResat: String { s("home.rateResat") }
        static var ratesLoading: String { s("home.ratesLoading") }
        static var ratesLoadingAccessibility: String { s("home.ratesLoadingAccessibility") }
        /// "Dolar ₺40"
        static func rateItem(_ label: String, _ value: String) -> String { s("home.rateItem", label, value) }
        static var totalRemaining: String { s("home.totalRemaining") }
        static var filterCredit: String { s("home.filterCredit") }
        static var filterCash: String { s("home.filterCash") }
        static var chipAllPaid: String { s("home.chipAllPaid") }
        /// "Bu ay: ₺22.500 kredi taksiti"
        static func chipDue(_ amount: String) -> String { s("home.chipDue", amount) }
    }
}
