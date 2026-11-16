import Foundation
import Testing
import UIKit
@testable import OdemeTakip

struct ImportFileTests {
    @Test func inboxCopyIsRemovedAfterImport() throws {
        let inbox = URL.documentsDirectory.appending(path: "Inbox")
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        let source = inbox.appending(path: "ekstre-\(UUID().uuidString).pdf")
        try Data("%PDF".utf8).write(to: source)

        let local = try ImportFile.copyToTemporary(source)
        #expect(FileManager.default.fileExists(atPath: local.path()))
        #expect(!FileManager.default.fileExists(atPath: source.path()))
    }

    @Test func filesOutsideInboxAreLeftAlone() throws {
        let source = FileManager.default.temporaryDirectory.appending(path: "keep-\(UUID().uuidString).pdf")
        try Data("%PDF".utf8).write(to: source)
        _ = try ImportFile.copyToTemporary(source)
        #expect(FileManager.default.fileExists(atPath: source.path()))
    }
}

struct LockedPDFTests {
    private func lockedPDF(password: String) throws -> URL {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextUserPassword as String: password,
                               kCGPDFContextOwnerPassword as String: password]
        let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842), format: format).pdfData { ctx in
            ctx.beginPage()
            NSAttributedString(string: "Taksit Tutarı: 4.812,35 TL — Taksit Sayısı: 36 — Garanti BBVA",
                               attributes: [.font: UIFont.systemFont(ofSize: 14)]).draw(at: CGPoint(x: 40, y: 60))
        }
        let url = FileManager.default.temporaryDirectory.appending(path: "locked-\(UUID().uuidString).pdf")
        try data.write(to: url)
        return url
    }

    @Test func lockedPDFAsksForPassword() async throws {
        let url = try lockedPDF(password: "1234")
        await #expect(throws: PDFTextExtractor.ExtractError.locked) {
            try await PDFTextExtractor.extractText(from: url)
        }
    }

    @Test func wrongPasswordIsReported() async throws {
        let url = try lockedPDF(password: "1234")
        await #expect(throws: PDFTextExtractor.ExtractError.wrongPassword) {
            try await PDFTextExtractor.extractText(from: url, password: "0000")
        }
    }

    @Test func rightPasswordUnlocksText() async throws {
        let url = try lockedPDF(password: "1234")
        let text = try await PDFTextExtractor.extractText(from: url, password: "1234")
        #expect(text.contains("Taksit Sayısı: 36"))
    }
}
