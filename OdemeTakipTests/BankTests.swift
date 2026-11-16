import Testing
@testable import OdemeTakip

struct BankTests {
    @Test func iconValueRoundTrips() {
        for bank in Bank.allCases {
            #expect(Bank(icon: bank.iconValue) == bank)
        }
    }

    @Test func emojiAndUnknownIconsAreNotBanks() {
        #expect(Bank(icon: "🏦") == nil)
        #expect(Bank(icon: "bank:") == nil)
        #expect(Bank(icon: "bank:unknown") == nil)
    }

    @Test func namesAndMonogramsComeFromCatalog() {
        #expect(Bank.isbank.name == "İş Bankası")
        #expect(Bank.ziraat.name == "Ziraat Bankası")
        #expect(Bank.isbank.monogram == "İŞ")
        #expect(Bank.qnb.monogram == "QNB")
        for bank in Bank.allCases {
            #expect(!bank.name.hasPrefix("banks."))
            #expect(!bank.monogram.hasPrefix("banks."))
        }
    }
}
