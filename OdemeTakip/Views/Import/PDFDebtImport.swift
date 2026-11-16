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
    /// Şifreli PDF'in geçici kopyası; parola sorulurken tutulur.
    @State private var lockedFile: URL?
    @State private var password = ""
    @State private var wrongPassword = false

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
            .alert(L10n.Documents.passwordTitle, isPresented: Binding(
                get: { lockedFile != nil },
                set: { if !$0, let file = lockedFile { lockedFile = nil; discard(file) } })) {
                SecureField(L10n.Documents.password, text: $password)
                Button(L10n.Documents.open) {
                    guard let file = lockedFile else { return }
                    lockedFile = nil
                    read(file, password: password)
                }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(wrongPassword ? L10n.Documents.wrongPassword : L10n.Documents.passwordMessage)
            }
            .alert(L10n.Documents.importUnreadable, isPresented: $unreadable) {
                Button(L10n.Common.close, role: .cancel) {}
            } message: {
                Text(L10n.Documents.importUnreadableMessage)
            }
    }

    private func start(_ url: URL) {
        guard !reading, lockedFile == nil else { return }
        do {
            read(try ImportFile.copyToTemporary(url), password: nil)
        } catch {
            unreadable = true
        }
    }

    /// Metni çıkarır ve ayrıştırır (ana iş parçacığı dışında); şifreliyse parola sorar.
    private func read(_ file: URL, password: String?) {
        reading = true
        Task {
            defer { reading = false }
            do {
                let text = try await PDFTextExtractor.extractText(from: file, password: password)
                let today = YearMonth(date: .now)
                let parsed = await Task.detached { BankDocumentParser.parse(text, today: today) }.value
                discard(file)
                self.password = ""
                wrongPassword = false
                imported = ImportedDebt(parsed: parsed)
            } catch PDFTextExtractor.ExtractError.locked {
                wrongPassword = false
                lockedFile = file
            } catch PDFTextExtractor.ExtractError.wrongPassword {
                self.password = ""
                wrongPassword = true
                lockedFile = file
            } catch {
                discard(file)
                unreadable = true
            }
        }
    }

    private func discard(_ file: URL) {
        try? FileManager.default.removeItem(at: file)
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
