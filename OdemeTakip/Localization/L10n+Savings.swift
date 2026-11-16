import Foundation

/// `Savings.xcstrings`: birikim ana sayfası, birikim detayı, hareket ve birikim formu.
extension L10n {
    enum Savings {
        private static func s(_ key: String, _ args: CVarArg...) -> String {
            L10n.string(key, table: "Savings", args: args)
        }

        static var filterAssets: String { s("savings.filterAssets") }
        static var filterReceivables: String { s("savings.filterReceivables") }
        static var totalWealth: String { s("savings.totalWealth") }
        static var legendSavings: String { s("savings.legendSavings") }
        static var legendReceivables: String { s("savings.legendReceivables") }
        static var emptyTitle: String { s("savings.emptyTitle") }
        static var emptyMessage: String { s("savings.emptyMessage") }
        static var addAsset: String { s("savings.addAsset") }
        static var addReceivable: String { s("savings.addReceivable") }
        static var newRecord: String { s("savings.newRecord") }
        /// "50 gr · Gram altın"
        static func goldSubtitle(_ quantity: String, _ unitName: String) -> String {
            s("savings.goldSubtitle", quantity, unitName)
        }
        static var kind: String { s("savings.kind") }
        /// "Miktar (gram)"
        static func quantityWithUnit(_ unit: String) -> String { s("savings.quantityWithUnit", unit) }
        static var quantity: String { s("savings.quantity") }
        static var deleteRecord: String { s("savings.deleteRecord") }
        static var newAsset: String { s("savings.newAsset") }
        static var deleteConfirmTitle: String { s("savings.deleteConfirmTitle") }
        static var deleteConfirmMessage: String { s("savings.deleteConfirmMessage") }
        static var noMovements: String { s("savings.noMovements") }
        /// "· 20 Eki"
        static func movementDay(_ day: String) -> String { s("savings.movementDay", day) }
        static var movementsHeader: String { s("savings.movementsHeader") }
        static var depositButton: String { s("savings.depositButton") }
        static var withdrawButton: String { s("savings.withdrawButton") }
        static var liraValue: String { s("savings.liraValue") }
        static var rateWaiting: String { s("savings.rateWaiting") }
        static var liraSavings: String { s("savings.liraSavings") }
        /// "1 gr — fiyat bekleniyor"
        static func priceWaiting(_ one: String) -> String { s("savings.priceWaiting", one) }
        /// "1 gr = ₺6.000 (satış)"
        static func priceSelling(_ one: String, _ price: String) -> String { s("savings.priceSelling", one, price) }
        static var withdrawAll: String { s("savings.withdrawAll") }
        /// "Mevcut: 50 gr"
        static func available(_ amount: String) -> String { s("savings.available", amount) }
        static var withdrawTitle: String { s("savings.withdrawTitle") }
        static var depositTitle: String { s("savings.depositTitle") }
    }
}
