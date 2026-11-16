import Foundation
import Testing
@testable import OdemeTakip

struct BankDocumentParserTests {
    private let today = YearMonth(year: 2026, month: 11)

    private func parse(_ text: String) -> ParsedDebt {
        BankDocumentParser.parse(text, today: today)
    }

    // MARK: Kredi bilgilendirme

    private let loanSummary = """
    GARANTİ BBVA
    İhtiyaç Kredisi Bilgilendirme Formu
    Kredi Tutarı: 100.000,00 TL
    Taksit Tutarı: 4.812,35 TL
    Taksit Sayısı: 36
    İlk Taksit Tarihi: 15.01.2026
    Toplam Geri Ödeme Tutarı: 173.244,60 TL
    """

    @Test func loanSummaryLabelsAreRead() {
        let p = parse(loanSummary)
        #expect(p.bank == .garanti)
        #expect(p.kind == .credit)
        #expect(p.monthlyAmount == Decimal(string: "4812.35"))
        #expect(p.installmentCount == 36)
        #expect(p.firstMonth == YearMonth(year: 2026, month: 1))
        #expect(p.currency == .TRY)
    }

    @Test func paidCountIsEstimatedFromFirstMonth() {
        let p = parse(loanSummary)
        #expect(p.paidCount == 10)
        #expect(p.foundFields.contains(.paidCount))
    }

    @Test func explicitPaidCountWins() {
        let p = parse(loanSummary + "\nÖdenen Taksit Sayısı: 7")
        #expect(p.paidCount == 7)
    }

    @Test func loanDraftIsValidAndUsesBankIcon() {
        let draft = parse(loanSummary).makeDraft(today: today)
        #expect(draft.isValid)
        #expect(draft.kind == .credit)
        #expect(draft.icon == "bank:garanti")
        #expect(draft.name == "\(Bank.garanti.name) kredisi")
        #expect(draft.monthlyAmount == Decimal(string: "4812.35"))
        #expect(draft.installmentCount == 36)
        #expect(draft.prepaidCount == 10)
        #expect(draft.firstMonth == YearMonth(year: 2026, month: 1))
    }

    // MARK: Ödeme planı tablosu

    private let paymentPlan = """
    TÜRKİYE İŞ BANKASI A.Ş.
    ÖDEME PLANI
    Taksit No  Vade Tarihi  Taksit Tutarı  Anapara  Faiz  BSMV
    1  05/03/2026  2.150,00  1.700,00  400,00  50,00
    2  05/04/2026  2.150,00  1.720,00  380,00  50,00
    3  05/05/2026  2.150,00  1.740,00  360,00  50,00
    4  05/06/2026  2.155,10  1.760,00  345,10  50,00
    """

    @Test func paymentPlanTableGivesCountFirstMonthAndMonthly() {
        let p = parse(paymentPlan)
        #expect(p.bank == .isbank)
        #expect(p.kind == .credit)
        #expect(p.installmentCount == 4)
        #expect(p.firstMonth == YearMonth(year: 2026, month: 3))
        #expect(p.monthlyAmount == 2150)
    }

    // MARK: Kredi kartı ekstresi

    private let cardStatement = """
    AKBANK T.A.Ş. Axess
    Hesap Özeti
    Dönem Borcu: 12.345,67 TL
    Asgari Ödeme Tutarı: 4.938,27 TL
    Son Ödeme Tarihi: 28.11.2026
    """

    @Test func cardStatementBecomesCashDebt() {
        let p = parse(cardStatement)
        #expect(p.bank == .akbank)
        #expect(p.kind == .cash)
        #expect(p.totalDebt == Decimal(string: "12345.67"))
        let draft = p.makeDraft(today: today)
        #expect(draft.isValid)
        #expect(draft.kind == .cash)
        #expect(draft.name == "\(Bank.akbank.name) kredi kartı")
    }

    // MARK: OCR ve düzen farkları

    @Test func ocrTextWithoutTurkishLettersStillParses() {
        let p = parse("""
        vakifbank   konut kredisi
        taksit tutari    1.250,00 tl
        vade sayisi 12
        ilk taksit tarihi 01 aralik 2026
        """)
        #expect(p.bank == .vakifbank)
        #expect(p.monthlyAmount == 1250)
        #expect(p.installmentCount == 12)
        #expect(p.firstMonth == YearMonth(year: 2026, month: 12))
        #expect(p.paidCount == 0)
    }

    @Test func valueOnNextLineIsRead() {
        let p = parse("""
        Taksit Tutarı
        3.000,00 TL
        Taksit Sayısı
        24
        """)
        #expect(p.monthlyAmount == 3000)
        #expect(p.installmentCount == 24)
    }

    @Test func monthlyIsDerivedFromTotalAndCount() {
        let p = parse("""
        Ziraat Bankası
        Toplam Geri Ödeme Tutarı: 12.000,00 TL
        Vade: 12 ay
        """)
        #expect(p.bank == .ziraat)
        #expect(p.installmentCount == 12)
        #expect(p.monthlyAmount == 1000)
    }

    @Test func foreignCurrencyIsDetected() {
        let p = parse("Taksit Tutarı: 500,00 USD\nTaksit Sayısı: 12")
        #expect(p.currency == .USD)
        #expect(p.monthlyAmount == 500)
    }

    @Test func unrelatedTextFindsNothing() {
        let p = parse("Merhaba, toplantı yarın saat 10:00'da.")
        #expect(p.isEmpty)
        #expect(p.bank == nil)
        #expect(p.foundFields.isEmpty)
        #expect(!p.makeDraft(today: today).isValid)
    }

    @Test func bannerListsReadFields() {
        var p = ParsedDebt()
        p.kind = .credit
        p.monthlyAmount = 100
        p.installmentCount = 12
        #expect(p.bannerText == "PDF'ten okunanlar: taksit tutarı, taksit sayısı. Kaydetmeden önce kontrol et.")
        #expect(ParsedDebt().bannerText == "Belgeden borç bilgisi okunamadı. Bilgileri elle girebilirsin.")
    }

    @Test func foundFieldsListWhatWasRead() {
        let p = parse(loanSummary)
        #expect(Set(p.foundFields) == [.bank, .monthlyAmount, .installmentCount, .firstMonth, .paidCount])
    }
}
