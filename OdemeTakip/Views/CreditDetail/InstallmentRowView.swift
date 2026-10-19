import SwiftUI

struct InstallmentRowView: View {
    let row: InstallmentRow
    let amount: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if row.isPaid {
                    Circle().fill(Theme.paid)
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(Theme.background)
                } else {
                    Circle().strokeBorder(Theme.ring, lineWidth: 2)
                }
            }
            .frame(width: 24, height: 24)

            HStack(spacing: 4) {
                Text(row.month.longLabel).fontWeight(row.isCurrent ? .bold : .regular)
                Text("· \(row.index + 1). taksit\(row.isCurrent ? " · bu ay" : "")")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            .lineLimit(1)

            Spacer(minLength: 8)

            Text(amount)
                .monospacedDigit()
                .foregroundStyle(row.isPaid ? Theme.paid : (row.isCurrent ? Color.white : Theme.secondaryText))
        }
        .font(.subheadline)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(row.isPaid ? "Ödendi" : "Ödenmedi")
    }
}
