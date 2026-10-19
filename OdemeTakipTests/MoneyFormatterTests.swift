import Foundation
import Testing
@testable import OdemeTakip

struct MoneyFormatterTests {
    @Test func wholeAmountsHaveNoFraction() {
        #expect(MoneyFormatter.string(15_000, .TRY) == "₺15.000")
        #expect(MoneyFormatter.string(2_400, .USD) == "$2.400")
        #expect(MoneyFormatter.string(0, .TRY) == "₺0")
    }

    @Test func fractionalAmountsShowTwoDigits() {
        #expect(MoneyFormatter.string(Decimal(string: "1234.5") ?? 0, .EUR) == "€1.234,50")
    }

    @Test func joinedOrdersByCurrencyAndSkipsZero() {
        let text = MoneyFormatter.joined([.USD: 2_400, .TRY: 50_000, .EUR: 0])
        #expect(text == "₺50.000 + $2.400")
    }

    @Test func joinedEmptyIsZeroLira() {
        #expect(MoneyFormatter.joined([:]) == "₺0")
    }

    @Test func goldAmountsUseUnitNames() {
        #expect(MoneyFormatter.string(50, .gram) == "50 gr")
        #expect(MoneyFormatter.string(Decimal(string: "12.5") ?? 0, .gram) == "12,50 gr")
        #expect(MoneyFormatter.string(12, .ceyrek) == "12 çeyrek")
        #expect(MoneyFormatter.string(2, .yarim) == "2 yarım")
        #expect(MoneyFormatter.string(1, .tam) == "1 tam")
        #expect(MoneyFormatter.string(3, .resat) == "3 reşat")
    }

    @Test func joinedListsGoldAfterFiat() {
        #expect(MoneyFormatter.joined([.ceyrek: 3, .TRY: 50_000, .gram: 10]) == "₺50.000 + 10 gr + 3 çeyrek")
    }

    @Test func signedShowsMinusForNegativeNet() {
        #expect(MoneyFormatter.signed(-12_000) == "−₺12.000")
        #expect(MoneyFormatter.signed(5) == "₺5")
    }
}
