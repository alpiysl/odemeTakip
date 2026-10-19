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
    @ObservationIgnored private var isRefreshing = false

    init(defaults: UserDefaults = .standard, fetch: @escaping Fetch = RateStore.fetchTCMB) {
        self.defaults = defaults
        self.fetch = fetch
        if let data = defaults.data(forKey: Self.key) {
            rates = try? JSONDecoder().decode(ExchangeRates.self, from: data)
        }
    }

    func refreshIfNeeded(now: Date = .now) async {
        if let rates, now.timeIntervalSince(rates.fetchedAt) < Self.maxAge { return }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let data = try await fetch()
            guard let fresh = TCMBParser.parse(data, fetchedAt: now) else {
                Log.app.error("TCMB response could not be parsed")
                return
            }
            rates = fresh
            if let encoded = try? JSONEncoder().encode(fresh) {
                defaults.set(encoded, forKey: Self.key)
            }
        } catch {
            Log.app.error("Rate fetch failed: \(error.localizedDescription, privacy: .public)")
        }
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
