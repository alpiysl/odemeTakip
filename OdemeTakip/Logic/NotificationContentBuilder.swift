import Foundation

struct NotificationContent: Equatable, Sendable {
    let title: String
    let body: String
}

enum NotificationContentBuilder {
    static let hour = 9

    static func content(for month: YearMonth, payments: [PaymentSnapshot],
                        rates: ExchangeRates? = nil) -> NotificationContent? {
        var lines: [String] = []

        let due = PaymentCalculator.dueUnpaid(payments, in: month)
        if !due.isEmpty {
            let amounts = due.mapValues(\.amount)
            let count = due.values.reduce(0) { $0 + $1.count }
            lines.append("Kredi: \(MoneyFormatter.total(amounts, rates: rates)) (\(count) taksit)")
        }

        let cash = PaymentCalculator.totals(payments).cash
        if !cash.isEmpty {
            lines.append("Elden kalan: \(MoneyFormatter.total(cash, rates: rates))")
        }

        guard !lines.isEmpty else { return nil }
        return NotificationContent(title: "\(month.name) ödemeleri", body: lines.joined(separator: "\n"))
    }

    static func triggerDate(for month: YearMonth, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: month.year, month: month.month, day: 1, hour: hour)) ?? .distantPast
    }

    /// `now` sonrasındaki ilk `count` adet "ayın 1'i 09:00" anının ayları.
    static func triggerMonths(after now: Date, count: Int = 12,
                              calendar: Calendar = AppCalendar.calendar) -> [YearMonth] {
        var result: [YearMonth] = []
        var month = YearMonth(date: now, calendar: calendar)
        while result.count < count {
            if triggerDate(for: month, calendar: calendar) > now {
                result.append(month)
            }
            month = month.adding(months: 1)
        }
        return result
    }
}
