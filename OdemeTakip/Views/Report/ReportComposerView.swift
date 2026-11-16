import PDFKit
import SwiftUI

/// Rapor oluşturma: bölümleri ve kayıtları seç, ay aralığı ver, PDF'i oluştur.
struct ReportComposerView: View {
    let payments: [Payment]
    let assets: [Asset]

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<UUID>
    @State private var sections = Set(ReportSection.allCases)
    @State private var limitRange = false
    @State private var from = YearMonth(date: .now).adding(months: -2)
    @State private var to = YearMonth(date: .now).adding(months: 3)
    @State private var previewURL: URL?
    @State private var failed = false

    init(payments: [Payment], assets: [Asset]) {
        self.payments = payments
        self.assets = assets
        _selected = State(initialValue: Set(payments.map(\.id) + assets.map(\.id)))
    }

    private var debts: [Payment] { payments.filter { $0.kind != .receivable } }
    private var receivables: [Payment] { payments.filter { $0.kind == .receivable } }

    /// Açık bölümlerde görünen kayıtların kimlikleri.
    private var visibleIDs: Set<UUID> {
        var ids = Set(debts.map(\.id))
        if sections.contains(.receivables) { ids.formUnion(receivables.map(\.id)) }
        if sections.contains(.savings) { ids.formUnion(assets.map(\.id)) }
        return ids
    }

    private var options: ReportOptions {
        let range = limitRange ? min(from, to)...max(from, to) : nil
        return ReportOptions(selectedIDs: selected.intersection(visibleIDs), sections: sections, range: range)
    }

    var body: some View {
        NavigationStack {
            Form {
                sectionsSection
                if visibleIDs.isEmpty {
                    Section { Text(L10n.Documents.empty).foregroundStyle(Theme.secondaryText) }
                        .listRowBackground(Theme.surface)
                } else {
                    recordsSection
                }
                rangeSection
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(L10n.Documents.createReport)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Documents.generate, action: generate)
                        .fontWeight(.semibold)
                        .disabled(!options.canGenerate)
                        .accessibilityIdentifier("generateReport")
                }
            }
            .navigationDestination(item: $previewURL) { url in
                ReportPreviewView(url: url)
            }
            .alert(L10n.Documents.failed, isPresented: $failed) {
                Button(L10n.Common.close, role: .cancel) {}
            }
        }
        .tint(Theme.accent)
        .appColorScheme()
    }

    private var sectionsSection: some View {
        Section {
            ForEach(ReportSection.allCases) { section in
                Toggle(section.title, isOn: Binding(
                    get: { sections.contains(section) },
                    set: { on in
                        if on { sections.insert(section) } else { sections.remove(section) }
                    }))
            }
        } header: {
            Text(L10n.Documents.sections)
        } footer: {
            Text(L10n.Documents.sectionsFooter)
        }
        .listRowBackground(Theme.surface)
    }

    private var recordsSection: some View {
        Section {
            ForEach(debts) { RecordToggleRow(icon: $0.icon, name: $0.name, detail: $0.kind.title, id: $0.id, selected: $selected) }
            if sections.contains(.receivables) {
                ForEach(receivables) { RecordToggleRow(icon: $0.icon, name: $0.name, detail: $0.kind.title, id: $0.id, selected: $selected) }
            }
            if sections.contains(.savings) {
                ForEach(assets) { RecordToggleRow(icon: $0.icon, name: $0.name, detail: L10n.Documents.sectionSavings, id: $0.id, selected: $selected) }
            }
        } header: {
            HStack {
                Text(L10n.Documents.records)
                Spacer()
                let allOn = visibleIDs.isSubset(of: selected)
                Button(allOn ? L10n.Documents.selectNone : L10n.Documents.selectAll) {
                    if allOn { selected.subtract(visibleIDs) } else { selected.formUnion(visibleIDs) }
                }
                .font(.caption.weight(.semibold))
                .textCase(nil)
            }
        }
        .listRowBackground(Theme.surface)
    }

    private var rangeSection: some View {
        Section {
            Toggle(L10n.Documents.limitRange, isOn: $limitRange.animation())
            if limitRange {
                MonthPicker(title: L10n.Documents.from, selection: $from)
                MonthPicker(title: L10n.Documents.to, selection: $to)
            }
        } header: {
            Text(L10n.Documents.dateRange)
        } footer: {
            Text(L10n.Documents.rangeFooter)
        }
        .listRowBackground(Theme.surface)
    }

    private func generate() {
        let data = ReportBuilder.build(payments: payments.map(ReportPaymentInput.init),
                                       assets: assets.map(ReportAssetInput.init),
                                       options: options)
        let directory = FileManager.default.temporaryDirectory.appending(path: "Reports")
        do {
            previewURL = try ReportPDFRenderer.write(data, to: directory)
        } catch {
            failed = true
        }
    }
}

/// Kayıt seçimi: dokununca rapora eklenir/çıkarılır.
private struct RecordToggleRow: View {
    let icon: String
    let name: String
    let detail: String
    let id: UUID
    @Binding var selected: Set<UUID>

    var body: some View {
        let isOn = selected.contains(id)
        Button {
            if isOn { selected.remove(id) } else { selected.insert(id) }
        } label: {
            HStack(spacing: 12) {
                PaymentIconView(icon: icon, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).foregroundStyle(Theme.primaryText)
                    Text(detail).font(.caption).foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? Theme.accent : Theme.ring)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

/// Oluşturulan PDF'in önizlemesi ve paylaşımı.
struct ReportPreviewView: View {
    let url: URL

    var body: some View {
        PDFKitView(url: url)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(url.deletingPathExtension().lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: url)
                        .accessibilityIdentifier("shareReport")
                }
            }
    }
}

private struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.backgroundColor = .secondarySystemBackground
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url { view.document = PDFDocument(url: url) }
    }
}
