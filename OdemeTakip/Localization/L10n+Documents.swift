import Foundation

/// `Documents.xcstrings`: dekont paylaşımı, PDF rapor ve PDF'ten borç ekleme.
extension L10n {
    enum Documents {
        private static func s(_ key: String, _ args: CVarArg...) -> String {
            L10n.string(key, table: "Documents", args: args)
        }

        // MARK: Dekont
        static var paymentDone: String { s("documents.receipt.paymentDone") }
        static var collectionDone: String { s("documents.receipt.collectionDone") }
        static var installmentDone: String { s("documents.receipt.installmentDone") }
        /// "Taksit 3/12"
        static func installmentOf(_ number: Int, _ count: Int) -> String { s("documents.receipt.installmentOf", number, count) }
        /// "20 Eki 2026"
        static func fullDate(_ dayMonth: String, _ year: Int) -> String { s("documents.receipt.fullDate", dayMonth, String(year)) }
        static var remaining: String { s("documents.receipt.remaining") }
        static var remainingReceivable: String { s("documents.receipt.remainingReceivable") }
        static var completed: String { s("documents.receipt.completed") }
        static var fileNamePrefix: String { s("documents.receipt.fileNamePrefix") }
        static var shareReceipt: String { s("documents.receipt.share") }
        static var footer: String { s("documents.receipt.footer") }

        // MARK: Rapor
        static var reportTitle: String { s("documents.report.title") }
        /// "Oluşturulma: 16 Kas 2026"
        static func generated(_ date: String) -> String { s("documents.report.generated", date) }
        /// "Ekim 2026 – Kasım 2026"
        static func range(_ from: String, _ to: String) -> String { s("documents.report.range", from, to) }
        static var sectionSummary: String { s("documents.report.sectionSummary") }
        static var sectionSchedule: String { s("documents.report.sectionSchedule") }
        static var sectionHistory: String { s("documents.report.sectionHistory") }
        static var sectionReceivables: String { s("documents.report.sectionReceivables") }
        static var sectionSavings: String { s("documents.report.sectionSavings") }
        static var sectionDebts: String { s("documents.report.sectionDebts") }
        static var remainingDebt: String { s("documents.report.remainingDebt") }
        static var remainingReceivableTotal: String { s("documents.report.remainingReceivableTotal") }
        static var recordCount: String { s("documents.report.recordCount") }
        static var total: String { s("documents.report.total") }
        static var paid: String { s("documents.report.paid") }
        static var collected: String { s("documents.report.collected") }
        static var statusPaid: String { s("documents.report.statusPaid") }
        static var statusPending: String { s("documents.report.statusPending") }
        /// "Kredi · ₺1.000 × 4"
        static func creditSubtitle(_ kind: String, _ monthly: String, _ count: Int) -> String {
            s("documents.report.creditSubtitle", kind, monthly, count)
        }
        static var columnNumber: String { s("documents.report.columnNumber") }
        static var columnMonth: String { s("documents.report.columnMonth") }
        static var columnAmount: String { s("documents.report.columnAmount") }
        static var columnStatus: String { s("documents.report.columnStatus") }
        static var columnDate: String { s("documents.report.columnDate") }
        /// "Sayfa 2/3"
        static func page(_ number: Int, _ count: Int) -> String { s("documents.report.page", number, count) }
        static var fileNamePrefixReport: String { s("documents.report.fileNamePrefix") }
        static var createReport: String { s("documents.report.create") }
        static var sections: String { s("documents.report.sections") }
        static var sectionsFooter: String { s("documents.report.sectionsFooter") }
        static var records: String { s("documents.report.records") }
        static var selectAll: String { s("documents.report.selectAll") }
        static var selectNone: String { s("documents.report.selectNone") }
        static var dateRange: String { s("documents.report.dateRange") }
        static var limitRange: String { s("documents.report.limitRange") }
        static var rangeFooter: String { s("documents.report.rangeFooter") }
        static var from: String { s("documents.report.from") }
        static var to: String { s("documents.report.to") }
        static var generate: String { s("documents.report.generate") }
        static var failed: String { s("documents.report.failed") }
        static var empty: String { s("documents.report.empty") }

        // MARK: PDF'ten borç
        /// "Garanti BBVA kredisi"
        static func loanName(_ bank: String) -> String { s("documents.import.loanName", bank) }
        /// "Akbank kredi kartı"
        static func cardName(_ bank: String) -> String { s("documents.import.cardName", bank) }
        static var fieldBank: String { s("documents.import.fieldBank") }
        static var fieldMonthly: String { s("documents.import.fieldMonthly") }
        static var fieldCount: String { s("documents.import.fieldCount") }
        static var fieldFirstMonth: String { s("documents.import.fieldFirstMonth") }
        static var fieldPaidCount: String { s("documents.import.fieldPaidCount") }
        static var fieldTotalDebt: String { s("documents.import.fieldTotalDebt") }
        /// "PDF'ten okunanlar: taksit tutarı, taksit sayısı. …"
        static func importFound(_ fields: String) -> String { s("documents.import.found", fields) }
        static var importNothingFound: String { s("documents.import.nothingFound") }
        static var importFromPDF: String { s("documents.import.fromPDF") }
        static var importManual: String { s("documents.import.manual") }
        static var importReading: String { s("documents.import.reading") }
        static var importUnreadable: String { s("documents.import.unreadable") }
        static var importUnreadableMessage: String { s("documents.import.unreadableMessage") }
    }
}
