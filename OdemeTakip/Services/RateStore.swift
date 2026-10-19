import Foundation
import Observation

/// Son TCMB kurunu tutar, saklar ve gerekirse yeniler. Hata durumunda sessizce eskiyi korur.
@MainActor
@Observable
final class RateStore {
    typealias Fetch = @Sendable () async throws -> Data

    static let maxAge: TimeInterval = 6 * 3600
    private static let key = "exchangeRates"

    private(set) var rates: ExchangeRates?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let fetch: Fetch
    @ObservationIgnored private let fetchGold: Fetch
    @ObservationIgnored private var isRefreshing = false

    init(defaults: UserDefaults = .standard, fetch: @escaping Fetch = RateStore.fetchTCMB,
         fetchGold: @escaping Fetch = RateStore.fetchMarket) {
        self.defaults = defaults
        self.fetch = fetch
        self.fetchGold = fetchGold
        if let data = defaults.data(forKey: Self.key) {
            rates = try? JSONDecoder().decode(ExchangeRates.self, from: data)
        }
    }

    /// `force`: uygulama sıfırdan açılınca önbellek taze olsa da yeniden çeker.
    func refreshIfNeeded(now: Date = .now, force: Bool = false) async {
        // Taze ve altın fiyatları da varsa ağa çıkma (eski sürüm önbelleğinde altın yok).
        if !force, let rates, rates.gold?.isEmpty == false, now.timeIntervalSince(rates.fetchedAt) < Self.maxAge { return }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        async let tcmbData = Self.load(fetch, name: "TCMB")
        async let marketData = Self.load(fetchGold, name: "market")
        let tcmb = await tcmbData.flatMap { TCMBParser.parse($0, fetchedAt: now) }
        let market = await marketData.flatMap(GoldParser.parse)
        if tcmb == nil, market == nil { return }

        var merged = tcmb ?? rates
        if merged == nil, let market, let usd = market.usd, let eur = market.eur {
            merged = ExchangeRates(usd: usd, eur: eur, bulletinDate: now, fetchedAt: now)
        }
        guard var merged else { return }
        if let market {
            merged.gold = Dictionary(uniqueKeysWithValues: market.gold.map { ($0.key.rawValue, $0.value) })
        } else if merged.gold == nil {
            merged.gold = rates?.gold
        }
        rates = merged
        if let encoded = try? JSONEncoder().encode(merged) {
            defaults.set(encoded, forKey: Self.key)
        }
    }

    private static func load(_ fetch: Fetch, name: String) async -> Data? {
        do {
            return try await fetch()
        } catch {
            Log.app.error("\(name, privacy: .public) fetch failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    nonisolated static let fetchMarket: Fetch = {
        guard let url = URL(string: "https://finans.truncgil.com/v4/today.json") else { throw URLError(.badURL) }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    nonisolated static let fetchTCMB: Fetch = {
        guard let url = URL(string: "https://www.tcmb.gov.tr/kurlar/today.xml") else { throw URLError(.badURL) }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        request.setValue("application/xml", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }
}
