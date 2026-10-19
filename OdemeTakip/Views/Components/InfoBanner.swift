import SwiftUI

struct InfoBanner: View {
    let text: String
    let onClose: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill").foregroundStyle(Theme.accent)
            Text(text).font(.footnote).foregroundStyle(.white.opacity(0.85))
            Spacer(minLength: 0)
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(Theme.secondaryText)
                }
                .accessibilityLabel("Kapat")
            }
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
