import Foundation
import PDFKit
import Testing
@testable import OdemeTakip

struct ReportPDFRendererTests {
    private let now = AppCalendar.calendar.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 9))!

    private func data(installments: Int, selectFriend: Bool = true) -> ReportData {
        let car = ReportPaymentInput(id: UUID(), name: "Araç Kredisi", icon: "🚗",
                                     snapshot: .credit(count: installments, monthly: 1000,
                                                       first: YearMonth(year: 2026, month: 1), paid: [0]),
                                     cashPayments: [])
        let friend = ReportPaymentInput(id: UUID(), name: "Ahmet Borcu", icon: "🤝",
                                        snapshot: .cash(debt: 500), cashPayments: [])
        let gold = ReportAssetInput(id: UUID(), name: "Çeyrek Altın", icon: "🪙", unit: .ceyrek, quantity: 3)
        var ids: Set<UUID> = [car.id, gold.id]
        if selectFriend { ids.insert(friend.id) }
        return ReportBuilder.build(payments: [car, friend], assets: [gold],
                                   options: ReportOptions(selectedIDs: ids), now: now)
    }

    @Test func pdfContainsSelectedItemsOnly() throws {
        let pdf = try #require(PDFDocument(data: ReportPDFRenderer.render(data(installments: 3, selectFriend: false))))
        let text = try #require(pdf.string)
        #expect(text.contains("Ödeme Raporu"))
        #expect(text.contains("Araç Kredisi"))
        #expect(text.contains("Çeyrek Altın"))
        #expect(!text.contains("Ahmet Borcu"))
    }

    @Test func shortReportFitsOnePage() throws {
        let pdf = try #require(PDFDocument(data: ReportPDFRenderer.render(data(installments: 3))))
        #expect(pdf.pageCount == 1)
        #expect(pdf.page(at: 0)?.string?.contains("Sayfa 1/1") == true)
    }

    @Test func longScheduleSpillsOntoMorePagesWithNumbering() throws {
        let pdf = try #require(PDFDocument(data: ReportPDFRenderer.render(data(installments: 120))))
        #expect(pdf.pageCount > 1)
        let last = pdf.pageCount
        #expect(pdf.page(at: last - 1)?.string?.contains("Sayfa \(last)/\(last)") == true)
        #expect(pdf.string?.contains("120") == true)
    }

    @Test func fileNameIsDated() {
        #expect(ReportPDFRenderer.fileName(date: now) == "Rapor-2026-11-16.pdf")
    }

    @Test func writesFileToDirectory() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let url = try ReportPDFRenderer.write(data(installments: 2), to: dir, date: now)
        #expect(url.lastPathComponent == "Rapor-2026-11-16.pdf")
        #expect(PDFDocument(url: url)?.pageCount == 1)
    }
}
