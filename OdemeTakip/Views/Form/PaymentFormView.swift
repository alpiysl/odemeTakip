import SwiftData
import SwiftUI

struct PaymentFormView: View {
    enum Mode {
        case create
        case edit(Payment)
    }

    let mode: Mode
    var onDeleteRequested: (() -> Void)? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var draft: PaymentDraft
    @State private var confirmingDelete = false
    @FocusState private var focusedField: String?

    init(mode: Mode, onDeleteRequested: (() -> Void)? = nil) {
        self.mode = mode
        self.onDeleteRequested = onDeleteRequested
        switch mode {
        case .create: _draft = State(initialValue: PaymentDraft(firstMonth: YearMonth(date: .now)))
        case .edit(let payment): _draft = State(initialValue: payment.makeDraft())
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if !draft.isEditing {
                    Section {
                        Picker("Tür", selection: $draft.kind) {
                            ForEach(PaymentKind.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                    }
                }

                Section {
                    TextField("Ad", text: $draft.name)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: "Ad")
                    Picker("İkon", selection: $draft.icon) {
                        ForEach(PaymentDraft.icons, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Para birimi", selection: $draft.currency) {
                        ForEach(Currency.fiatCases) { Text($0.displayName).tag($0) }
                    }
                }
                .listRowBackground(Theme.surface)

                if draft.kind == .credit {
                    Section {
                        numberField("Taksit sayısı", text: $draft.installmentCountText, decimal: false)
                        numberField("Aylık tutar", text: $draft.monthlyAmountText, decimal: true)
                        MonthPicker(title: "İlk taksit ayı", selection: $draft.firstMonth)
                        if !draft.isEditing {
                            numberField("Ödenmiş taksit sayısı", text: $draft.prepaidCountText, decimal: false)
                        }
                    }
                    .listRowBackground(Theme.surface)
                } else {
                    Section {
                        numberField("Toplam borç", text: $draft.totalDebtText, decimal: true)
                    }
                    .listRowBackground(Theme.surface)
                }

                if let preview = draft.preview {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Toplam \(MoneyFormatter.string(PaymentCalculator.total(preview), preview.currency)) · Kalan \(MoneyFormatter.string(PaymentCalculator.remaining(preview), preview.currency))")
                                .font(.subheadline.weight(.semibold))
                            if let last = PaymentCalculator.lastInstallmentMonth(preview) {
                                Text("Son taksit: \(last.longLabel)").font(.caption).foregroundStyle(Theme.secondaryText)
                            }
                        }
                    }
                    .listRowBackground(Theme.credit.opacity(0.1))
                } else if draft.hasInput, let message = draft.visibleValidationMessage {
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
            .background(Theme.background)
            .navigationTitle(draft.isEditing ? "Düzenle" : "Yeni ödeme")
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
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: draft.icon) { focusedField = nil }
            .onChange(of: draft.currency) { focusedField = nil }
            .onChange(of: draft.firstMonth) { focusedField = nil }
            .onChange(of: draft.kind) { _, newKind in
                focusedField = nil
                if PaymentKind.allCases.map(PaymentDraft.defaultIcon(for:)).contains(draft.icon) {
                    draft.icon = PaymentDraft.defaultIcon(for: newKind)
                }
            }
            .confirmationDialog("Bu kayıt silinsin mi?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Sil", role: .destructive) {
                    onDeleteRequested?()
                    dismiss()
                }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("Tüm ödeme geçmişi de silinir.")
            }
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
    }

    private func numberField(_ title: String, text: Binding<String>, decimal: Bool) -> some View {
        LabeledContent(title) {
            TextField("0", text: text)
                .keyboardType(decimal ? .decimalPad : .numberPad)
                .focused($focusedField, equals: title)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
    }

    private func save() {
        switch mode {
        case .create:
            guard let payment = Payment.make(from: draft) else { return }
            context.insert(payment)
        case .edit(let payment):
            guard payment.apply(draft) else { return }
        }
        context.saveQuietly()
        dismiss()
    }
}
