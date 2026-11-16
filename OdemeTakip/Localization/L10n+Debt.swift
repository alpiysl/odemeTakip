import Foundation

/// `Debt.xcstrings`: kredi ve elden borç / alacak detayları, ödeme ekleme.
extension L10n {
    enum Debt {
        private static func s(_ key: String, _ args: CVarArg...) -> String {
            L10n.string(key, table: "Debt", args: args)
        }

        static func showPaid(_ count: Int) -> String { s("debt.showPaid", count) }
        static var hidePaid: String { s("debt.hidePaid") }
        /// "36 taksit · ₺15.000/ay · Eyl 2025 başlangıç"
        static func creditInfo(_ count: Int, _ monthly: String, _ start: String) -> String { s("debt.creditInfo", count, monthly, start) }
        /// "13/36 taksit ödendi"
        static func paidOf(_ paid: Int, _ total: Int) -> String { s("debt.paidOf", paid, total) }
        static func next(_ month: String) -> String { s("debt.next", month) }
        static var completed: String { s("debt.completed") }
        static var tapHint: String { s("debt.tapHint") }
        static var total: String { s("debt.total") }
        static func paidCount(_ count: Int) -> String { s("debt.paidCount", count) }
        static func remainingCount(_ count: Int) -> String { s("debt.remainingCount", count) }
        /// "· 14. taksit" / "· 14. taksit · bu ay"
        static func installmentSuffix(_ number: Int, current: Bool) -> String {
            current ? s("debt.installmentSuffixCurrent", number) : s("debt.installmentSuffix", number)
        }
        static var paid: String { s("debt.paid") }
        static var unpaid: String { s("debt.unpaid") }
        static var payAllReceivable: String { s("debt.payAllReceivable") }
        static var payAllDebt: String { s("debt.payAllDebt") }
        static func remainingFooter(_ remaining: String) -> String { s("debt.remainingFooter", remaining) }
        static func remainingFooter(_ remaining: String, lira: String) -> String { s("debt.remainingFooterWithLira", remaining, lira) }
        static var addCollectionTitle: String { s("debt.addCollectionTitle") }
        static var addPaymentTitle: String { s("debt.addPaymentTitle") }
        static var noCollections: String { s("debt.noCollections") }
        static var noPayments: String { s("debt.noPayments") }
        /// "· 20 Eki"
        static func historyDay(_ day: String) -> String { s("debt.historyDay", day) }
        static var collectionHistory: String { s("debt.collectionHistory") }
        static var paymentHistory: String { s("debt.paymentHistory") }
        static func receivableInfo(_ total: String) -> String { s("debt.receivableInfo", total) }
        static func cashInfo(_ total: String) -> String { s("debt.cashInfo", total) }
        static var receivableCompleted: String { s("debt.receivableCompleted") }
        static var debtCompleted: String { s("debt.debtCompleted") }
        static var addCollectionButton: String { s("debt.addCollectionButton") }
        static var addPaymentButton: String { s("debt.addPaymentButton") }
        static var totalReceivable: String { s("debt.totalReceivable") }
        static var totalDebt: String { s("debt.totalDebt") }
        static func collectedCount(_ count: Int) -> String { s("debt.collectedCount", count) }
        static var remainingReceivable: String { s("debt.remainingReceivable") }
        static var remaining: String { s("debt.remaining") }
        static var progress: String { s("debt.progress") }
        static func progressValue(_ percent: Int) -> String { s("debt.progressValue", percent) }
    }
}
