import SwiftUI

/// Detay ekranının sağ üst köşesi: ana sayfadaki başlık gibi ayrı, gri, zeminsiz ikonlar —
/// rapor (`doc.text`) ve düzenle (kalem). iOS 26'da araç çubuğu düğmeleri tek cam kapsülde
/// birleşmesin diye her biri kendi öğesinde ve ortak zemin gizli.
struct RecordToolbar: ToolbarContent {
    let onReport: () -> Void
    let onEdit: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            RecordToolbarIcon(systemImage: "doc.text", label: L10n.Documents.reportForRecord,
                              identifier: "recordReportButton", action: onReport)
        }
        .hidingSharedBackground()
        ToolbarItem(placement: .primaryAction) {
            RecordToolbarIcon(systemImage: "pencil", label: L10n.Common.edit,
                              identifier: "editButton", action: onEdit)
        }
        .hidingSharedBackground()
    }
}

private struct RecordToolbarIcon: View {
    let systemImage: String
    let label: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}

private extension ToolbarContent {
    /// iOS 26: düğmenin cam kapsül zeminini kaldırır; önceki sürümlerde zaten yok.
    @ToolbarContentBuilder
    func hidingSharedBackground() -> some ToolbarContent {
        if #available(iOS 26.0, *) {
            sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}
