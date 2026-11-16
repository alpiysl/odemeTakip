import Foundation

enum AppCalendar {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "tr_TR")
        calendar.timeZone = .current
        return calendar
    }
}

enum TurkishMonths {
    /// Ay adları `Common.xcstrings` dosyasından: "Ocak", "Şubat", ...
    static var names: [String] { (1...12).map(L10n.Common.month) }
    static var shortNames: [String] { (1...12).map(L10n.Common.monthShort) }

    static func dayMonth(_ date: Date, calendar: Calendar = AppCalendar.calendar) -> String {
        let comps = calendar.dateComponents([.day, .month], from: date)
        let day = comps.day ?? 1
        let month = min(max((comps.month ?? 1) - 1, 0), 11)
        return L10n.Common.dayMonth(day, L10n.Common.monthShort(month + 1))
    }
}

struct YearMonth: Hashable, Comparable, Sendable, Codable {
    let year: Int
    /// 1...12
    let month: Int

    init(year: Int, month: Int) {
        let total = year * 12 + (month - 1)
        let normalizedYear = Int((Double(total) / 12).rounded(.down))
        self.year = normalizedYear
        self.month = total - normalizedYear * 12 + 1
    }

    init(date: Date, calendar: Calendar = AppCalendar.calendar) {
        let comps = calendar.dateComponents([.year, .month], from: date)
        self.init(year: comps.year ?? 2000, month: comps.month ?? 1)
    }

    func adding(months: Int) -> YearMonth {
        YearMonth(year: year, month: month + months)
    }

    func months(from other: YearMonth) -> Int {
        (year * 12 + month) - (other.year * 12 + other.month)
    }

    func firstDay(calendar: Calendar = AppCalendar.calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? .distantPast
    }

    var name: String { L10n.Common.month(month) }
    var longLabel: String { L10n.Common.monthYear(name, year) }
    var shortLabel: String { L10n.Common.monthYear(L10n.Common.monthShort(month), year) }

    static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        lhs.months(from: rhs) < 0
    }
}
