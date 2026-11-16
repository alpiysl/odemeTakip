import SwiftUI
import UniformTypeIdentifiers

/// WhatsApp vb. ile paylaşılan dekont kartı. Her zaman açık temada çizilir.
struct ReceiptCardView: View {
    let receipt: Receipt

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(spacing: 18) {
                HStack(spacing: 12) {
                    PaymentIconView(icon: receipt.icon, size: 44, tint: Theme.kindColor(receipt.kind))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(receipt.title)
                            .font(.headline)
                            .lineLimit(2)
                        Text(receipt.dateText)
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    Spacer(minLength: 0)
                }

                VStack(spacing: 4) {
                    Text(receipt.amountText)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    if let detail = receipt.detailText {
                        Text(detail)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(receipt.remainingTitle).foregroundStyle(Theme.secondaryText)
                        Spacer()
                        Text(receipt.remainingText).fontWeight(.semibold).monospacedDigit()
                    }
                    .font(.subheadline)
                    ProgressBar(fraction: receipt.progress, color: Theme.paid, height: 6)
                }

                Divider().overlay(Theme.divider)

                Text(L10n.Documents.footer)
                    .font(.caption)
                    .foregroundStyle(Theme.tertiaryText)
            }
            .padding(20)
        }
        .foregroundStyle(Theme.primaryText)
        .frame(width: 360)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(16)
        .background(Theme.background)
        .environment(\.colorScheme, .light)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
            Text(receipt.headline)
                .font(.headline)
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(receipt.kind == .receivable ? Theme.savingsGradient : Theme.gradient)
    }
}

/// Dekontun PNG olarak paylaşılan hâli; `ShareLink` ile kullanılır.
struct ReceiptImage: Transferable {
    let receipt: Receipt

    @MainActor
    func pngData() -> Data? {
        let renderer = ImageRenderer(content: ReceiptCardView(receipt: receipt))
        renderer.scale = 3
        return renderer.uiImage?.pngData()
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            guard let data = await item.pngData() else { throw CocoaError(.fileWriteUnknown) }
            return data
        }
        .suggestedFileName { $0.receipt.fileName }
    }
}

/// Satırlara eklenen "Dekontu paylaş" bağlantısı.
struct ShareReceiptLink: View {
    let receipt: Receipt

    var body: some View {
        ShareLink(item: ReceiptImage(receipt: receipt),
                  preview: SharePreview(receipt.title + " · " + receipt.amountText)) {
            Label(L10n.Documents.shareReceipt, systemImage: "square.and.arrow.up")
        }
    }
}

#Preview {
    ReceiptCardView(receipt: .installment(
        index: 2,
        snapshot: .credit(count: 12, monthly: 7500, first: YearMonth(year: 2026, month: 8), paid: [0, 1, 2]),
        name: "Araç Kredisi", icon: "bank:garanti")!)
}
