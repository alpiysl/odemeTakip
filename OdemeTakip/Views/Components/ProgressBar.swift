import SwiftUI

/// İnce yatay ilerleme çubuğu (ödenen / toplam).
struct ProgressBar: View {
    let fraction: Double
    var color: Color = Theme.paid
    var height: CGFloat = 4

    var body: some View {
        Capsule()
            .fill(Theme.track)
            .frame(height: height)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * min(max(fraction, 0), 1))
                }
            }
            .accessibilityElement()
            .accessibilityLabel("İlerleme")
            .accessibilityValue("Yüzde \(Int((min(max(fraction, 0), 1) * 100).rounded()))")
    }
}

extension PaymentCalculator {
    /// Ödenen / toplam, 0…1. Toplam yoksa 0.
    static func progress(_ p: PaymentSnapshot) -> Double {
        let total = total(p)
        guard total > 0 else { return 0 }
        return NSDecimalNumber(decimal: paid(p) / total).doubleValue
    }

    /// İlk ödenmemiş taksitin ayı; hepsi ödendiyse nil.
    static func nextUnpaidMonth(_ p: PaymentSnapshot) -> YearMonth? {
        guard p.kind == .credit else { return nil }
        return (0..<max(p.installmentCount, 0))
            .first { !p.paidInstallments.contains($0) }
            .map { installmentMonth(p, index: $0) }
    }
}

/// Boş liste görünümü: ikon + başlık + açıklama.
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Theme.tertiaryText)
                .padding(.bottom, 4)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
            Image(systemName: "arrow.down")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.tertiaryText)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
        .accessibilityElement(children: .combine)
    }
}
