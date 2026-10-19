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
}
