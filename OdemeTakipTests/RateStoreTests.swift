import Foundation
import Testing
@testable import OdemeTakip

private struct FetchFailed: Error {}

@MainActor
struct RateStoreTests {
    let defaults: UserDefaults

    init() {
        let suite = "RateStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
    }

    private let xml = Data(ExchangeRatesTests.sampleXML.utf8)
    private let market = Data(GoldPricesTests.sampleJSON.utf8)

    @Test func refreshStoresAndPersistsRates() async {
        let store = RateStore(defaults: defaults, fetch: { [xml] in xml }, fetchGold: { throw FetchFailed() })
        #expect(store.rates == nil)
        await store.refreshIfNeeded()
        #expect(store.rates?.usd == Decimal(string: "49.5523"))

        let reloaded = RateStore(defaults: defaults, fetch: { throw FetchFailed() }, fetchGold: { throw FetchFailed() })
        #expect(reloaded.rates?.eur == Decimal(string: "57.7138"))
    }

    @Test func failedFetchKeepsLastRatesSilently() async {
        let seeded = RateStore(defaults: defaults, fetch: { [xml] in xml }, fetchGold: { throw FetchFailed() })
        await seeded.refreshIfNeeded()

        let offline = RateStore(defaults: defaults, fetch: { throw FetchFailed() }, fetchGold: { throw FetchFailed() })
        await offline.refreshIfNeeded(now: .now.addingTimeInterval(7 * 3600))
        #expect(offline.rates?.usd == Decimal(string: "49.5523"))
    }

    @Test func garbageResponseKeepsLastRates() async {
        let seeded = RateStore(defaults: defaults, fetch: { [xml] in xml }, fetchGold: { throw FetchFailed() })
        await seeded.refreshIfNeeded()

        let broken = RateStore(defaults: defaults, fetch: { Data("<html/>".utf8) }, fetchGold: { throw FetchFailed() })
        await broken.refreshIfNeeded(now: .now.addingTimeInterval(7 * 3600))
        #expect(broken.rates?.usd == Decimal(string: "49.5523"))
    }

    @Test func freshRatesSkipNetwork() async {
        let seeded = RateStore(defaults: defaults, fetch: { [xml] in xml }, fetchGold: { [market] in market })
        await seeded.refreshIfNeeded()

        let counter = Counter()
        let store = RateStore(defaults: defaults, fetch: { await counter.hit(); return Data() }, fetchGold: { throw FetchFailed() })
        await store.refreshIfNeeded(now: .now.addingTimeInterval(3600))
        #expect(await counter.value == 0)
        await store.refreshIfNeeded(now: .now.addingTimeInterval(7 * 3600))
        #expect(await counter.value == 1)
    }

    @Test func goldPricesMergeIntoRates() async {
        let store = RateStore(defaults: defaults, fetch: { [xml] in xml }, fetchGold: { [market] in market })
        await store.refreshIfNeeded()
        #expect(store.rates?.usd == Decimal(string: "49.5523"))
        #expect(store.rates?.rate(for: .ceyrek) == Decimal(string: "10804.61"))
        #expect(store.rates?.rate(for: .resat) == Decimal(string: "44672.29"))
    }

    @Test func goldFailureKeepsPreviousGold() async {
        let seeded = RateStore(defaults: defaults, fetch: { [xml] in xml }, fetchGold: { [market] in market })
        await seeded.refreshIfNeeded()

        let store = RateStore(defaults: defaults, fetch: { [xml] in xml }, fetchGold: { throw FetchFailed() })
        await store.refreshIfNeeded(now: .now.addingTimeInterval(7 * 3600))
        #expect(store.rates?.rate(for: .gram) == Decimal(string: "6602.36"))
    }

    @Test func tcmbDownWithoutCacheUsesMarketFiat() async {
        let store = RateStore(defaults: defaults, fetch: { throw FetchFailed() }, fetchGold: { [market] in market })
        await store.refreshIfNeeded()
        #expect(store.rates?.usd == Decimal(string: "49.5591"))
        #expect(store.rates?.rate(for: .gram) == Decimal(string: "6602.36"))
    }

    @Test func oldCacheWithoutGoldStillLoads() throws {
        let old = #"{"usd":40,"eur":50,"bulletinDate":0,"fetchedAt":0}"#
        defaults.set(Data(old.utf8), forKey: "exchangeRates")
        let store = RateStore(defaults: defaults, fetch: { throw FetchFailed() }, fetchGold: { throw FetchFailed() })
        #expect(store.rates?.usd == 40)
        #expect(store.rates?.rate(for: .gram) == nil)
    }

    @Test func freshCacheWithoutGoldStillFetchesGold() async {
        // Önceki sürüm: sadece TCMB kuru, 1 saat önce alınmış.
        let old = ExchangeRates(usd: 40, eur: 50, bulletinDate: .now, fetchedAt: .now.addingTimeInterval(-3600))
        defaults.set(try? JSONEncoder().encode(old), forKey: "exchangeRates")

        let store = RateStore(defaults: defaults, fetch: { [xml] in xml }, fetchGold: { [market] in market })
        await store.refreshIfNeeded()
        #expect(store.rates?.rate(for: .gram) == Decimal(string: "6602.36"))
    }

    @Test func launchRefreshIgnoresFreshCache() async {
        let seeded = RateStore(defaults: defaults, fetch: { [xml] in xml }, fetchGold: { [market] in market })
        await seeded.refreshIfNeeded()

        let counter = Counter()
        let store = RateStore(defaults: defaults,
                              fetch: { [xml] in await counter.hit(); return xml },
                              fetchGold: { [market] in market })
        await store.refreshIfNeeded(now: .now.addingTimeInterval(60), force: true)
        #expect(await counter.value == 1)
    }
}

private actor Counter {
    var value = 0
    func hit() { value += 1 }
}
