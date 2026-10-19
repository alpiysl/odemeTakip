import SwiftData
import SwiftUI

struct AssetFormView: View {
    enum Mode {
        case create
        case edit(Asset)
    }

    let mode: Mode
    var onDeleteRequested: (() -> Void)? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var draft: AssetDraft
    @State private var confirmingDelete = false
    @FocusState private var focusedField: String?

    init(mode: Mode, onDeleteRequested: (() -> Void)? = nil) {
        self.mode = mode
        self.onDeleteRequested = onDeleteRequested
        switch mode {
        case .create: _draft = State(initialValue: AssetDraft())
        case .edit(let asset): _draft = State(initialValue: asset.makeDraft())
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ad", text: $draft.name)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: "Ad")
                    Picker("İkon", selection: $draft.icon) {
                        ForEach(AssetDraft.icons, id: \.self) { Text($0).tag($0) }
                    }
                    if !draft.isEditing {
                        Picker("Tür", selection: $draft.unit) {
                            ForEach(Currency.allCases) { Text($0.displayName).tag($0) }
                        }
                    }
                }
                .listRowBackground(Theme.surface)

                if !draft.isEditing {
                    Section {
                        LabeledContent(draft.unit.isGold ? "Miktar (\(draft.unit.unitName))" : "Tutar") {
                            TextField("0", text: $draft.amountText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .monospacedDigit()
                                .focused($focusedField, equals: "Miktar")
                        }
                    }
                    .listRowBackground(Theme.surface)
                }

                if !draft.name.isEmpty || !draft.amountText.isEmpty, let message = draft.visibleValidationMessage {
                    Section {
                        Text(message).font(.footnote).foregroundStyle(Theme.cash)
                    }
                    .listRowBackground(Color.clear)
                }

                if draft.isEditing {
                    Section {
                        Button("Kaydı sil", role: .destructive) { confirmingDelete = true }
                    }
                    .listRowBackground(Theme.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .navigationTitle(draft.isEditing ? "Düzenle" : "Yeni birikim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .fontWeight(.bold)
                        .disabled(!draft.isValid)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Bitti") { focusedField = nil }
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: draft.icon) { focusedField = nil }
            .onChange(of: draft.unit) { oldUnit, newUnit in
                focusedField = nil
                if draft.icon == AssetDraft.defaultIcon(for: oldUnit) {
                    draft.icon = AssetDraft.defaultIcon(for: newUnit)
                }
            }
            .confirmationDialog("Bu birikim silinsin mi?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Sil", role: .destructive) {
                    onDeleteRequested?()
                    dismiss()
                }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("Tüm hareket geçmişi de silinir.")
            }
        }
        .tint(Theme.paid)
        .preferredColorScheme(.dark)
    }

    private func save() {
        switch mode {
        case .create:
            guard Asset.make(from: draft, in: context) != nil else { return }
        case .edit(let asset):
            guard asset.apply(draft) else { return }
        }
        context.saveQuietly()
        dismiss()
    }
}
