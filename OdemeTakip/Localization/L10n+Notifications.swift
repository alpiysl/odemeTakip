import Foundation

/// `Notifications.xcstrings`: aylık bildirim içeriği.
extension L10n {
    enum Notifications {
        private static func s(_ key: String, _ args: CVarArg...) -> String {
            L10n.string(key, table: "Notifications", args: args)
        }

        /// "Kredi: ₺22.500 (2 taksit)"
        static func creditLine(_ total: String, _ count: Int) -> String { s("notifications.creditLine", total, count) }
        /// "Elden kalan: ₺146.000"
        static func cashLine(_ total: String) -> String { s("notifications.cashLine", total) }
        /// "Kasım ödemeleri"
        static func title(_ month: String) -> String { s("notifications.title", month) }
        static var noPayments: String { s("notifications.noPayments") }
    }
}
