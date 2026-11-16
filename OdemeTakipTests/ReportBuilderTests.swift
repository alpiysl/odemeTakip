import Foundation
import Testing
@testable import OdemeTakip

struct ReportBuilderTests {
    private let cal = AppCalendar.calendar
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }
    private let now = AppCalendar.calendar.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 9))!

    private var car: ReportPaymentInput {
        ReportPaymentInput(id: UUID(), name: "Araç", icon: "🚗",
                           snapshot: .credit(count: 4, monthly: 1000, first: YearMonth(year: 2026, month: 9), paid: [0, 1]),
                           cashPayments: [])
    }
    private var friend: ReportPaymentInput {
        ReportPaymentInput(id: UUID(), name: "Ahmet", icon: "🤝",
                           snapshot: .cash(debt: 500, paid: 300, paymentCount: 2),
                           cashPayments: [.init(amount: 100, date: day(2026, 9, 5)), .init(amount: 200, date: day(2026, 10, 7))])
    }
    private var dollars: ReportPaymentInput {
        ReportPaymentInput(id: UUID(), name: "Dolar borcu", icon: "💵",
                           snapshot: .cash(.USD, debt: 300), cashPayments: [])
    }
    private var receivable: ReportPaymentInput {
        var s = PaymentSnapshot.cash(debt: 800, paid: 0)
        s.kind = .receivable
        return ReportPaymentInput(id: UUID(), name: "Mehmet", icon: "💰", snapshot: s, cashPayments: [])
    }
    private let gold = ReportAssetInput(id: UUID(), name: "Altın", icon: "🪙", unit: .ceyrek, quantity: 3)

    private func build(_ payments: [ReportPaymentInput], assets: [ReportAssetInput] = [],
                       selected: Set<UUID>? = nil, sections: Set<ReportSection> = Set(ReportSection.allCases),
                       range: ClosedRange<YearMonth>? = nil) -> ReportData {
        let ids = selected ?? Set(payments.map(\.id) + assets.map(\.id))
        let options = ReportOptions(selectedIDs: ids, sections: sections, range: range)
        return ReportBuilder.build(payments: payments, assets: assets, options: options, now: now)
    }

    @Test func unselectedDebtIsLeftOutEverywhere() {
        let car = car, friend = friend
        let data = build([car, friend], selected: [friend.id])
        #expect(data.debts.map(\.title) == ["Ahmet"])
        #expect(data.summary.first { $0.label == "Kalan borç" }?.value == "₺200")
    }

    @Test func summaryTotalsRemainingPerCurrency() {
        let data = build([car, friend, dollars])
        #expect(data.summary.first { $0.label == "Kalan borç" }?.value == "₺2.200 + $300")
    }

    @Test func summarySectionOffMeansNoSummary() {
        let data = build([car], sections: [.schedule])
        #expect(data.summary.isEmpty)
    }

    @Test func creditBlockHasFactsAndSchedule() throws {
        let block = try #require(build([car]).debts.first)
        #expect(block.subtitle == "Kredi · ₺1.000 × 4")
        #expect(block.facts.map(\.value) == ["₺4.000", "₺2.000", "₺2.000"])
        #expect(block.rows.count == 4)
        #expect(block.rows[0].cells == ["1", "Eylül 2026", "₺1.000", "Ödendi"])
        #expect(block.rows[2].cells[3] == "Bekliyor")
    }

    @Test func scheduleSectionOffHidesInstallmentRows() throws {
        let block = try #require(build([car], sections: [.summary]).debts.first)
        #expect(block.rows.isEmpty)
        #expect(!block.facts.isEmpty)
    }

    @Test func historyRowsAreNewestFirstAndHiddenWhenSectionOff() throws {
        let block = try #require(build([friend]).debts.first)
        #expect(block.rows.map { $0.cells[0] } == ["7 Eki 2026", "5 Eyl 2026"])
        let hidden = try #require(build([friend], sections: [.summary]).debts.first)
        #expect(hidden.rows.isEmpty)
    }

    @Test func dateRangeFiltersScheduleAndHistory() throws {
        let range = YearMonth(year: 2026, month: 10)...YearMonth(year: 2026, month: 11)
        let data = build([car, friend], range: range)
        #expect(data.debts[0].rows.map { $0.cells[1] } == ["Ekim 2026", "Kasım 2026"])
        #expect(data.debts[1].rows.map { $0.cells[0] } == ["7 Eki 2026"])
        #expect(data.rangeText == "Ekim 2026 – Kasım 2026")
    }

    @Test func receivablesNeedTheirSection() {
        let data = build([car, receivable])
        #expect(data.debts.map(\.title) == ["Araç"])
        #expect(data.receivables.map(\.title) == ["Mehmet"])
        #expect(data.summary.first { $0.label == "Kalan alacak" }?.value == "₺800")

        let without = build([car, receivable], sections: [.summary, .schedule])
        #expect(without.receivables.isEmpty)
        #expect(without.summary.first { $0.label == "Kalan alacak" } == nil)
    }

    @Test func savingsListsSelectedAssetsOnly() {
        let data = build([car], assets: [gold])
        #expect(data.savings == [ReportLine(label: "🪙 Altın", value: "3 çeyrek")])
        let none = build([car], assets: [gold], selected: [car.id])
        #expect(none.savings.isEmpty)
    }

    @Test func generatedTextUsesDate() {
        #expect(build([car]).generatedText == "Oluşturulma: 16 Kas 2026")
    }

    @Test func optionsCanGenerateOnlyWithSomethingSelected() {
        let id = UUID()
        #expect(!ReportOptions(selectedIDs: [], sections: [.summary]).canGenerate)
        #expect(!ReportOptions(selectedIDs: [id], sections: []).canGenerate)
        #expect(ReportOptions(selectedIDs: [id], sections: [.summary]).canGenerate)
    }
}
