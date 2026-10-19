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

    @Test func refreshStoresAndPersistsRates() async {
        let store = RateStore(defaults: defaults, fetch: { [xml] in xml })
        #expect(store.rates == nil)
        await store.refreshIfNeeded()
        #expect(store.rates?.usd == Decimal(string: "49.5523"))

        let reloaded = RateStore(defaults: defaults, fetch: { throw FetchFailed() })
        #expect(reloaded.rates?.eur == Decimal(string: "57.7138"))
    }

    @Test func failedFetchKeepsLastRatesSilently() async {
        let seeded = RateStore(defaults: defaults, fetch: { [xml] in xml })
        await seeded.refreshIfNeeded()

        let offline = RateStore(defaults: defaults, fetch: { throw FetchFailed() })
        await offline.refreshIfNeeded(now: .now.addingTimeInterval(7 * 3600))
        #expect(offline.rates?.usd == Decimal(string: "49.5523"))
    }

    @Test func garbageResponseKeepsLastRates() async {
        let seeded = RateStore(defaults: defaults, fetch: { [xml] in xml })
        await seeded.refreshIfNeeded()

        let broken = RateStore(defaults: defaults, fetch: { Data("<html/>".utf8) })
        await broken.refreshIfNeeded(now: .now.addingTimeInterval(7 * 3600))
        #expect(broken.rates?.usd == Decimal(string: "49.5523"))
    }

    @Test func freshRatesSkipNetwork() async {
        let seeded = RateStore(defaults: defaults, fetch: { [xml] in xml })
        await seeded.refreshIfNeeded()

        let counter = Counter()
        let store = RateStore(defaults: defaults, fetch: { await counter.hit(); return Data() })
        await store.refreshIfNeeded(now: .now.addingTimeInterval(3600))
        #expect(await counter.value == 0)
        await store.refreshIfNeeded(now: .now.addingTimeInterval(7 * 3600))
        #expect(await counter.value == 1)
    }
}

private actor Counter {
    var value = 0
    func hit() { value += 1 }
}
