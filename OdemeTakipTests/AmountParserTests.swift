import Foundation
import Testing
@testable import OdemeTakip

struct AmountParserTests {
    @Test(arguments: [
        ("15000", "15000"),
        ("15.000", "15000"),
        ("1.500.000", "1500000"),
        ("1.500,50", "1500.5"),
        ("1500,5", "1500.5"),
        ("12.5", "12.5"),
        (" ₺7.500 ", "7500"),
        ("0", "0"),
    ])
    func parsesTurkishInput(input: String, expected: String) {
        #expect(AmountParser.parse(input) == Decimal(string: expected))
    }

    @Test(arguments: ["", "abc", "-5", "1,999", "1,2,3", "12.34.5", "1.50.000"])
    func rejectsInvalidInput(input: String) {
        #expect(AmountParser.parse(input) == nil)
    }

    @Test func editingTextRoundTrips() {
        let value = Decimal(string: "1500.5") ?? 0
        #expect(AmountParser.editingText(value) == "1500,5")
        #expect(AmountParser.editingText(7_500) == "7500")
        #expect(AmountParser.parse(AmountParser.editingText(value)) == value)
    }
}
