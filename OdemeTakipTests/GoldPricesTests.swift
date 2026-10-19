import Foundation
import Testing
@testable import OdemeTakip

struct GoldPricesTests {
    static let sampleJSON = """
    {"Update_Date":"2026-10-19 21:02:01",
     "USD":{"Buying":49.5448,"Type":"Currency","Selling":49.5591,"Change":0.06},
     "EUR":{"Buying":55.612,"Type":"Currency","Selling":55.6317,"Change":-0.15},
     "GRA":{"Selling":6602.36,"Type":"Gold","Name":"GRAMALTIN","Change":-0.46,"Buying":6601.5},
     "CEYREKALTIN":{"Buying":10563.22,"Type":"Gold","Selling":10804.61},
     "YARIMALTIN":{"Buying":21060.42,"Type":"Gold","Selling":21609.23},
     "TAMALTIN":{"Buying":42252.89,"Type":"Gold","Selling":43086.29},
     "RESATALTIN":{"Buying":43573.29,"Type":"Gold","Selling":44672.29}}
    """

    @Test func parsesGoldAndFiatSelling() throws {
        let prices = try #require(GoldParser.parse(Data(Self.sampleJSON.utf8)))
        #expect(prices.gold[.gram] == Decimal(string: "6602.36"))
        #expect(prices.gold[.ceyrek] == Decimal(string: "10804.61"))
        #expect(prices.gold[.yarim] == Decimal(string: "21609.23"))
        #expect(prices.gold[.tam] == Decimal(string: "43086.29"))
        #expect(prices.gold[.resat] == Decimal(string: "44672.29"))
        #expect(prices.usd == Decimal(string: "49.5591"))
        #expect(prices.eur == Decimal(string: "55.6317"))
    }

    @Test(arguments: ["", "{", "{\"Update_Date\":\"x\"}", "<html></html>"])
    func rejectsBrokenOrGoldlessResponse(text: String) {
        #expect(GoldParser.parse(Data(text.utf8)) == nil)
    }

    @Test func convertsGoldToLira() {
        let rates = ExchangeRates(usd: 40, eur: 50, bulletinDate: .now, fetchedAt: .now,
                                  gold: [Currency.gram.rawValue: 6_000, Currency.ceyrek.rawValue: 10_000])
        #expect(CurrencyConverter.toTRY([.gram: 10, .ceyrek: 2, .TRY: 500], rates: rates) == Decimal(80_500))
        #expect(CurrencyConverter.toTRY([.tam: 1], rates: rates) == nil)
    }
}
