import SwiftUI
import UniformTypeIdentifiers

/// PDF'ten borç ekleme akışı: dosya seç (ya da "Birlikte aç" ile gelen dosya), metni oku,
/// bilgileri ayrıştır, önceden doldurulmuş formu aç.
struct PDFDebtImportModifier: ViewModifier {
    @Binding var isPickerPresented: Bool
    @Binding var incomingURL: URL?

    @State private var reading = false
    @State private var imported: ImportedDebt?
    @State private var unreadable = false

    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: $isPickerPresented, allowedContentTypes: [.pdf]) { result in
                if case .success(let url) = result { start(url) }
            }
            .onChange(of: incomingURL) { _, url in
                guard let url else { return }
                incomingURL = nil
                start(url)
            }
            .overlay {
                if reading {
                    ProgressView(L10n.Documents.importReading)
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .accessibilityIdentifier("importProgress")
                }
            }
            .sheet(item: $imported) { item in
                PaymentFormView(mode: .createFromImport(item.parsed))
            }
            .alert(L10n.Documents.importUnreadable, isPresented: $unreadable) {
                Button(L10n.Common.close, role: .cancel) {}
            } message: {
                Text(L10n.Documents.importUnreadableMessage)
            }
    }

    private func start(_ url: URL) {
        guard !reading else { return }
        reading = true
        Task {
            defer { reading = false }
            do {
                let local = try Self.copyToTemporary(url)
                defer { try? FileManager.default.removeItem(at: local) }
                let text = try await PDFTextExtractor.extractText(from: local)
                imported = ImportedDebt(parsed: BankDocumentParser.parse(text, today: YearMonth(date: .now)))
            } catch {
                unreadable = true
            }
        }
    }

    /// Dosya uygulamasından gelen adres güvenlik kapsamlıdır; okumak için geçici bir kopya alınır.
    private static func copyToTemporary(_ url: URL) throws -> URL {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let directory = FileManager.default.temporaryDirectory.appending(path: "Imports")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appending(path: UUID().uuidString + ".pdf")
        try FileManager.default.copyItem(at: url, to: destination)
        return destination
    }
}

private struct ImportedDebt: Identifiable {
    let id = UUID()
    let parsed: ParsedDebt
}

extension View {
    func pdfDebtImport(isPickerPresented: Binding<Bool>, incomingURL: Binding<URL?>) -> some View {
        modifier(PDFDebtImportModifier(isPickerPresented: isPickerPresented, incomingURL: incomingURL))
    }
}
