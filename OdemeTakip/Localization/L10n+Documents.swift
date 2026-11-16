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
    }
}
