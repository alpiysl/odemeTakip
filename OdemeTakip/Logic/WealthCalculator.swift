import Foundation

/// TL cinsinden varlık özeti. Kur/fiyat eksikse ilgili alan nil.
struct WealthSummary: Equatable, Sendable {
    var savings: Decimal?
    var receivable: Decimal?
    var debt: Decimal?

    /// Birikim + alacak − borç; herhangi biri hesaplanamazsa nil.
    var net: Decimal? {
        guard let savings, let receivable, let debt else { return nil }
        return savings + receivable - debt
    }
}

enum WealthCalculator {
    static func assetTotals(_ assets: [AssetSnapshot]) -> [Currency: Decimal] {
        var totals: [Currency: Decimal] = [:]
        for asset in assets where asset.quantity > 0 {
            totals[asset.unit, default: 0] += asset.quantity
        }
        return totals
    }

    static func summary(assets: [AssetSnapshot], payments: [PaymentSnapshot], rates: ExchangeRates?) -> WealthSummary {
        let totals = PaymentCalculator.totals(payments)
        return WealthSummary(
            savings: CurrencyConverter.toTRY(assetTotals(assets), rates: rates),
            receivable: CurrencyConverter.toTRY(totals.receivable, rates: rates),
            debt: CurrencyConverter.toTRY(totals.overall, rates: rates))
    }
}
