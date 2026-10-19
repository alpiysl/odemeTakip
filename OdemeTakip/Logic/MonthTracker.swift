import Foundation
import Observation

/// Ekranların kullandığı "bu ay". Uygulama ay dönümünde askıda kalsa da
/// öne gelince / saat değişince yenilenir.
@MainActor
@Observable
final class MonthTracker {
    private(set) var current: YearMonth

    init(now: Date = .now) {
        current = YearMonth(date: now)
    }

    func refresh(now: Date = .now) {
        let month = YearMonth(date: now)
        if month != current { current = month }
    }
}
