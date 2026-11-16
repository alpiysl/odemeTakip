import Foundation

/// `Forms.xcstrings`: borç / alacak formu ve ay seçici.
extension L10n {
    enum Forms {
        private static func s(_ key: String, _ args: CVarArg...) -> String {
            L10n.string(key, table: "Forms", args: args)
        }

        static var month: String { s("forms.month") }
        static var year: String { s("forms.year") }
        static var kind: String { s("forms.kind") }
        static var installmentCount: String { s("forms.installmentCount") }
        static var monthlyAmount: String { s("forms.monthlyAmount") }
        static var firstInstallmentMonth: String { s("forms.firstInstallmentMonth") }
        static var prepaidCount: String { s("forms.prepaidCount") }
        static var totalReceivable: String { s("forms.totalReceivable") }
        static var totalDebt: String { s("forms.totalDebt") }
        /// "Toplam ₺540.000 · Kalan ₺345.000"
        static func preview(_ total: String, _ remaining: String) -> String { s("forms.preview", total, remaining) }
        static func lastInstallment(_ month: String) -> String { s("forms.lastInstallment", month) }
        static var deleteRecord: String { s("forms.deleteRecord") }
        static var newReceivable: String { s("forms.newReceivable") }
        static var newPayment: String { s("forms.newPayment") }
        static var deleteConfirmTitle: String { s("forms.deleteConfirmTitle") }
        static var deleteConfirmMessage: String { s("forms.deleteConfirmMessage") }
    }
}
