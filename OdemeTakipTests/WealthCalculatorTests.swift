import Foundation
import Testing
@testable import OdemeTakip

struct WealthCalculatorTests {
    let rates = ExchangeRates(usd: 40, eur: 50, bulletinDate: .now, fetchedAt: .now,
                              gold: [Currency.gram.rawValue: 6_000, Currency.ceyrek.rawValue: 10_000])

    let assets = [
        AssetSnapshot(id: UUID(), unit: .gram, quantity: 10),
        AssetSnapshot(id: UUID(), unit: .gram, quantity: 5),
        AssetSnapshot(id: UUID(), unit: .USD, quantity: 1_000),
        AssetSnapshot(id: UUID(), unit: .TRY, quantity: 0),
    ]

    let payments: [PaymentSnapshot] = [
        .cash(debt: 30_000),
        .cash(.USD, debt: 100),
        PaymentSnapshot(kind: .receivable, currency: .ceyrek, totalDebt: 2),
    ]

    @Test func assetTotalsGroupByUnitAndSkipEmpty() {
        #expect(WealthCalculator.assetTotals(assets) == [.gram: 15, .USD: 1_000])
    }

    @Test func summaryConvertsEverythingToLira() {
        let s = WealthCalculator.summary(assets: assets, payments: payments, rates: rates)
        #expect(s.savings == Decimal(130_000))     // 15 gr × 6.000 + 1.000 $ × 40
        #expect(s.receivable == Decimal(20_000))   // 2 çeyrek × 10.000
        #expect(s.debt == Decimal(34_000))         // 30.000 + 100 $ × 40
        #expect(s.net == Decimal(116_000))
    }

    @Test func missingGoldPriceHidesNet() {
        let noGold = ExchangeRates(usd: 40, eur: 50, bulletinDate: .now, fetchedAt: .now)
        let s = WealthCalculator.summary(assets: assets, payments: payments, rates: noGold)
        #expect(s.savings == nil)
        #expect(s.receivable == nil)
        #expect(s.debt == Decimal(34_000))
        #expect(s.net == nil)
    }

    @Test func emptyIsZero() {
        let s = WealthCalculator.summary(assets: [], payments: [], rates: nil)
        #expect(s.savings == 0 && s.receivable == 0 && s.debt == 0 && s.net == 0)
    }
}
