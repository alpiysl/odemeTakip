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

    @Test(arguments: [
        ("TÜRKİYE İŞ BANKASI A.Ş.", Bank.isbank),
        ("Garanti BBVA", .garanti),
        ("AKBANK T.A.Ş.", .akbank),
        ("QNB Finansbank", .qnb),
        ("T. Halk Bankası", .halkbank),
        ("VakıfBank", .vakifbank),
        ("vakiflar bankasi", .vakifbank),
        ("T.C. Ziraat Bankası", .ziraat),
    ])
    func detectsBankInText(text: String, bank: Bank) {
        #expect(Bank.detect(in: "Hesap özeti\n\(text)\nMüşteri") == bank)
    }

    @Test func detectsNoBankInPlainText() {
        #expect(Bank.detect(in: "Market alışverişi 250,00 TL") == nil)
    }

    @Test func mostMentionedBankWins() {
        #expect(Bank.detect(in: "Garanti BBVA\nAkbank'a EFT\nGaranti müşteri hizmetleri") == .garanti)
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
