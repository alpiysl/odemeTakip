import Foundation
import PDFKit
import Vision

/// PDF'in metnini cihaz üzerinde çıkarır: önce gömülü metin, yoksa (taranmış belge) Vision ile OCR.
enum PDFTextExtractor {
    enum ExtractError: Error, Equatable {
        case unreadable
        /// Şifreli PDF; parola gerekiyor.
        case locked
        case wrongPassword
    }

    /// Bundan kısa gömülü metni olan sayfa taranmış sayılır (dijital altbilgi/filigran bu kadar uzun olmaz).
    private static let minimumPageTextLength = 200
    /// OCR en fazla bu kadar sayfaya uygulanır.
    private static let maxOCRPages = 10

    /// Sayfa sayfa okur: metni yeterli sayfa olduğu gibi, az metinli sayfa OCR ile.
    /// Çağıran görev iptal edilirse OCR durur ve `CancellationError` atılır.
    static func extractText(from url: URL, password: String? = nil) async throws -> String {
        try Task.checkCancellation()
        let work = Task.detached(priority: .userInitiated) { () throws -> String in
            guard let document = PDFDocument(url: url) else { throw ExtractError.unreadable }
            // Banka e-ekstreleri genellikle şifreli gelir (çoğunlukla TC kimlik no / doğum tarihi).
            if document.isLocked {
                guard let password, !password.isEmpty else { throw ExtractError.locked }
                guard document.unlock(withPassword: password) else { throw ExtractError.wrongPassword }
            }
            guard document.pageCount > 0 else { throw ExtractError.unreadable }
            var parts: [String] = []
            var ocrPages = 0
            for index in 0..<document.pageCount {
                try Task.checkCancellation()
                guard let page = document.page(at: index) else { continue }
                let embedded = page.string ?? ""
                if embedded.trimmingCharacters(in: .whitespacesAndNewlines).count >= minimumPageTextLength
                    || ocrPages >= maxOCRPages {
                    parts.append(embedded)
                    continue
                }
                ocrPages += 1
                let recognized = try autoreleasepool { try recognizeText(on: page) }
                parts.append([embedded, recognized].filter { !$0.isEmpty }.joined(separator: "\n"))
            }
            return parts.joined(separator: "\n")
        }
        return try await withTaskCancellationHandler {
            try await work.value
        } onCancel: {
            work.cancel()
        }
    }

    private static func recognizeText(on page: PDFPage) throws -> String {
        let bounds = page.bounds(for: .mediaBox)
        let image = page.thumbnail(of: CGSize(width: bounds.width * 2.5, height: bounds.height * 2.5), for: .mediaBox)
        guard let cgImage = image.cgImage else { return "" }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Tutarlar ve tarihler bozulmasın.
        request.usesLanguageCorrection = false
        let supported = (try? request.supportedRecognitionLanguages()) ?? []
        request.recognitionLanguages = ["tr-TR", "en-US"].filter(supported.contains)
        try VNImageRequestHandler(cgImage: cgImage).perform([request])
        return lines(from: request.results ?? [])
    }

    /// Aynı yükseklikteki gözlemleri (tablo sütunları) tek satırda birleştirir, yukarıdan aşağı sıralar.
    private static func lines(from observations: [VNRecognizedTextObservation]) -> String {
        let items = observations.compactMap { obs in
            obs.topCandidates(1).first.map { (box: obs.boundingBox, text: $0.string) }
        }
        .sorted { $0.box.midY > $1.box.midY }

        var rows: [[(box: CGRect, text: String)]] = []
        for item in items {
            if let last = rows.last?.first, abs(last.box.midY - item.box.midY) < min(last.box.height, item.box.height) * 0.5 {
                rows[rows.count - 1].append(item)
            } else {
                rows.append([item])
            }
        }
        return rows
            .map { $0.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: "  ") }
            .joined(separator: "\n")
    }
}
