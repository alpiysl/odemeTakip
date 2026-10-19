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
    static let names = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
                        "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]
    static let shortNames = ["Oca", "Şub", "Mar", "Nis", "May", "Haz",
                             "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"]

    static func dayMonth(_ date: Date, calendar: Calendar = AppCalendar.calendar) -> String {
        let comps = calendar.dateComponents([.day, .month], from: date)
        let day = comps.day ?? 1
        let month = min(max((comps.month ?? 1) - 1, 0), 11)
        return "\(day) \(shortNames[month])"
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

    var name: String { TurkishMonths.names[month - 1] }
    var longLabel: String { "\(name) \(year)" }
    var shortLabel: String { "\(TurkishMonths.shortNames[month - 1]) \(year)" }

    static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        lhs.months(from: rhs) < 0
    }
}
