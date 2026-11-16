import Foundation

/// `Validation.xcstrings`: form doğrulama mesajları.
extension L10n {
    enum Validation {
        private static func s(_ key: String, _ args: CVarArg...) -> String {
            L10n.string(key, table: "Validation", args: args)
        }

        static var nameRequired: String { s("validation.nameRequired") }
        static var invalidQuantity: String { s("validation.invalidQuantity") }
        static func withdrawExceedsAvailable(_ available: String) -> String { s("validation.withdrawExceedsAvailable", available) }
        static var invalidAmount: String { s("validation.invalidAmount") }
        static func exceedsRemainingDebt(_ remaining: String) -> String { s("validation.exceedsRemainingDebt", remaining) }
        static func exceedsRemainingReceivable(_ remaining: String) -> String { s("validation.exceedsRemainingReceivable", remaining) }
        static func installmentRange(_ max: Int) -> String { s("validation.installmentRange", max) }
        static func installmentBelowPaid(_ minimum: Int) -> String { s("validation.installmentBelowPaid", minimum) }
        static var invalidMonthlyAmount: String { s("validation.invalidMonthlyAmount") }
        static func prepaidRange(_ max: Int) -> String { s("validation.prepaidRange", max) }
        static var invalidTotalDebt: String { s("validation.invalidTotalDebt") }
        static func totalDebtBelowPaid(_ paid: String) -> String { s("validation.totalDebtBelowPaid", paid) }
        static var invalidTotalReceivable: String { s("validation.invalidTotalReceivable") }
        static func totalReceivableBelowCollected(_ collected: String) -> String { s("validation.totalReceivableBelowCollected", collected) }
    }
}
