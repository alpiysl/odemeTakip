import Foundation
import Testing
import UIKit
@testable import OdemeTakip

struct PDFTextExtractorTests {
    private let lines = ["Garanti BBVA", "Taksit Tutarı: 4.812,35 TL", "Taksit Sayısı: 36", "İlk Taksit Tarihi: 15.01.2026"]

    private func writePDF(_ name: String, draw: @escaping (CGRect) -> Void) throws -> URL {
        let bounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            draw(bounds)
        }
        let url = FileManager.default.temporaryDirectory.appending(path: "\(name)-\(UUID().uuidString).pdf")
        try data.write(to: url)
        return url
    }

    private func drawLines(at origin: CGPoint) {
        for (index, line) in lines.enumerated() {
            NSAttributedString(string: line, attributes: [.font: UIFont.systemFont(ofSize: 22), .foregroundColor: UIColor.black])
                .draw(at: CGPoint(x: origin.x, y: origin.y + CGFloat(index) * 40))
        }
    }

    @Test func readsEmbeddedText() async throws {
        let url = try writePDF("text") { _ in drawLines(at: CGPoint(x: 40, y: 60)) }
        let text = try await PDFTextExtractor.extractText(from: url)
        #expect(text.contains("Taksit Sayısı: 36"))
    }

    @Test func fallsBackToOCRForScannedPages() async throws {
        // Metni önce resme çevir, PDF'e yalnız resim olarak koy: taranmış belge gibi.
        let image = UIGraphicsImageRenderer(size: CGSize(width: 595, height: 842)).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 595, height: 842))
            drawLines(at: CGPoint(x: 40, y: 60))
        }
        let url = try writePDF("scan") { bounds in image.draw(in: bounds) }
        let text = try await PDFTextExtractor.extractText(from: url)
        let parsed = BankDocumentParser.parse(text, today: YearMonth(year: 2026, month: 11))
        #expect(parsed.installmentCount == 36, "OCR text: \(text)")
        #expect(parsed.monthlyAmount == Decimal(string: "4812.35"), "OCR text: \(text)")
    }

    @Test func scannedPageWithDigitalFooterIsStillRead() async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 595, height: 760)).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 595, height: 760))
            drawLines(at: CGPoint(x: 40, y: 60))
        }
        let url = try writePDF("footer") { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: 595, height: 760))
            NSAttributedString(string: "Bu belge elektronik ortamda oluşturulmuştur. Sayfa 1/1 www.banka.com.tr",
                               attributes: [.font: UIFont.systemFont(ofSize: 8)]).draw(at: CGPoint(x: 40, y: 800))
        }
        let text = try await PDFTextExtractor.extractText(from: url)
        let parsed = BankDocumentParser.parse(text, today: YearMonth(year: 2026, month: 11))
        #expect(parsed.installmentCount == 36, "text: \(text)")
    }

    @Test func cancellingStopsOCR() async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 595, height: 842)).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 595, height: 842))
            drawLines(at: CGPoint(x: 40, y: 60))
        }
        let bounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            for _ in 0..<10 { context.beginPage(); image.draw(in: bounds) }
        }
        let url = FileManager.default.temporaryDirectory.appending(path: "many-\(UUID().uuidString).pdf")
        try data.write(to: url)
        let task = Task { try await PDFTextExtractor.extractText(from: url) }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test func notAPDFThrows() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "not-\(UUID().uuidString).pdf")
        try Data("hello".utf8).write(to: url)
        await #expect(throws: PDFTextExtractor.ExtractError.unreadable) {
            try await PDFTextExtractor.extractText(from: url)
        }
    }
}
