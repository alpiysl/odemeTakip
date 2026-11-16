import Foundation

/// `Common.xcstrings`: birden çok ekranda geçen ortak metinler.
extension L10n {
    enum Common {
        private static func s(_ key: String, _ args: CVarArg...) -> String {
            L10n.string(key, table: "Common", args: args)
        }

        static var cancel: String { s("common.cancel") }
        static var save: String { s("common.save") }
        static var done: String { s("common.done") }
        static var edit: String { s("common.edit") }
        static var close: String { s("common.close") }
        static var delete: String { s("common.delete") }
        static var dismiss: String { s("common.dismiss") }
        static var date: String { s("common.date") }
        static var amount: String { s("common.amount") }
        static var all: String { s("common.all") }
        static var completedSection: String { s("common.completedSection") }
        static var icon: String { s("common.icon") }
        static var name: String { s("common.name") }
        static var currency: String { s("common.currency") }
        static var liraEquivalent: String { s("common.liraEquivalent") }
        /// "≈ ₺96.000"
        static func approx(_ value: String) -> String { s("common.approx", value) }
        static var storeUnavailable: String { s("common.storeUnavailable") }

        /// Ay adları, Ocak...Aralık.
        static var months: [String] {
            [s("common.month1"), s("common.month2"), s("common.month3"), s("common.month4"),
             s("common.month5"), s("common.month6"), s("common.month7"), s("common.month8"),
             s("common.month9"), s("common.month10"), s("common.month11"), s("common.month12")]
        }
        /// Kısa ay adları, Oca...Ara.
        static var monthsShort: [String] {
            [s("common.monthShort1"), s("common.monthShort2"), s("common.monthShort3"), s("common.monthShort4"),
             s("common.monthShort5"), s("common.monthShort6"), s("common.monthShort7"), s("common.monthShort8"),
             s("common.monthShort9"), s("common.monthShort10"), s("common.monthShort11"), s("common.monthShort12")]
        }
        /// Ay adı, 1...12: "Ocak"
        static func month(_ month: Int) -> String { months[month - 1] }
        /// Kısa ay adı, 1...12: "Oca"
        static func monthShort(_ month: Int) -> String { monthsShort[month - 1] }
        /// "20 Eki"
        static func dayMonth(_ day: Int, _ monthShort: String) -> String { s("common.dayMonth", day, monthShort) }
        /// "Ekim 2026"
        /// Yıl metin olarak geçer; `%lld` tr_TR'de binlik ayırıcı ekler ("2.026").
        static func monthYear(_ month: String, _ year: Int) -> String { s("common.monthYear", month, String(year)) }
    }
}
