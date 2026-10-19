import Foundation
import Testing
@testable import OdemeTakip

struct ExchangeRatesTests {
    static let sampleXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <Tarih_Date Tarih="19.10.2026" Date="10/19/2026" Bulten_No="2026/197">
      <Currency CrossOrder="0" Kod="USD" CurrencyCode="USD">
        <Unit>1</Unit><ForexBuying>49.4632</ForexBuying><ForexSelling>49.5523</ForexSelling>
      </Currency>
      <Currency CrossOrder="1" Kod="JPY" CurrencyCode="JPY">
        <Unit>100</Unit><ForexBuying>31.0</ForexBuying><ForexSelling>31.5</ForexSelling>
      </Currency>
      <Currency CrossOrder="9" Kod="EUR" CurrencyCode="EUR">
        <Unit>1</Unit><ForexBuying>57.6100</ForexBuying><ForexSelling>57.7138</ForexSelling>
      </Currency>
    </Tarih_Date>
    """

    let rates = ExchangeRates(usd: 40, eur: 50, bulletinDate: YearMonth(year: 2026, month: 10).firstDay(), fetchedAt: .now)

    @Test func parsesForexSellingForUsdAndEur() throws {
        let fetchedAt = Date(timeIntervalSince1970: 1_000)
        let parsed = try #require(TCMBParser.parse(Data(Self.sampleXML.utf8), fetchedAt: fetchedAt))
        #expect(parsed.usd == Decimal(string: "49.5523"))
        #expect(parsed.eur == Decimal(string: "57.7138"))
        #expect(parsed.fetchedAt == fetchedAt)
        let comps = AppCalendar.calendar.dateComponents([.year, .month, .day], from: parsed.bulletinDate)
        #expect(comps.year == 2026 && comps.month == 10 && comps.day == 19)
        #expect(parsed.label == "TCMB 19 Eki")
    }

    @Test(arguments: ["", "<html>Bakım</html>", "<Tarih_Date Tarih=\"19.10.2026\"></Tarih_Date>"])
    func rejectsBrokenOrIncompleteXML(xml: String) {
        #expect(TCMBParser.parse(Data(xml.utf8), fetchedAt: .now) == nil)
    }

    @Test func convertsMixedCurrenciesToLira() {
        let total = CurrencyConverter.toTRY([.TRY: 50_000, .USD: 2_400, .EUR: 100], rates: rates)
        #expect(total == Decimal(151_000))   // 50.000 + 96.000 + 5.000
    }

    @Test func convertedForeignAmountsRoundToWholeLira() {
        let r = ExchangeRates(usd: Decimal(string: "49.5523") ?? 0, eur: 50, bulletinDate: .now, fetchedAt: .now)
        #expect(CurrencyConverter.toTRY([.USD: 10], rates: r) == 496)   // 495,523 → 496
        #expect(CurrencyConverter.toTRY([.TRY: Decimal(string: "10.5") ?? 0], rates: r) == Decimal(string: "10.5"))
    }

    @Test func withoutRatesOnlyPureLiraConverts() {
        #expect(CurrencyConverter.toTRY([.TRY: 1_000], rates: nil) == 1_000)
        #expect(CurrencyConverter.toTRY([:], rates: nil) == 0)
        #expect(CurrencyConverter.toTRY([.TRY: 1_000, .USD: 5], rates: nil) == nil)
    }

    @Test func displayFallsBackToSeparateCurrencies() {
        #expect(MoneyFormatter.total([.TRY: 50_000, .USD: 2_400], rates: rates) == "₺146.000")
        #expect(MoneyFormatter.total([.TRY: 50_000, .USD: 2_400], rates: nil) == "₺50.000 + $2.400")
    }

    @Test func notificationUsesLiraTotalsWhenRatesExist() {
        let nov = YearMonth(year: 2026, month: 11)
        let payments: [PaymentSnapshot] = [
            .credit(count: 12, monthly: 1_000, first: nov),
            .credit(.USD, count: 12, monthly: 10, first: nov),
            .cash(debt: 50_000),
            .cash(.USD, debt: 2_400),
        ]
        let content = NotificationContentBuilder.content(for: nov, payments: payments, rates: rates)
        #expect(content?.body == "Kredi: ₺1.400 (2 taksit)\nElden kalan: ₺146.000")
        let fallback = NotificationContentBuilder.content(for: nov, payments: payments, rates: nil)
        #expect(fallback?.body == "Kredi: ₺1.000 + $10 (2 taksit)\nElden kalan: ₺50.000 + $2.400")
    }
}
