import SwiftData
import SwiftUI

struct PaymentFormView: View {
    enum Mode {
        case create
        case createReceivable
        /// Banka PDF'inden okunan bilgilerle önceden doldurulmuş yeni borç.
        case createFromImport(ParsedDebt)
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
        case .createReceivable:
            var draft = PaymentDraft(firstMonth: YearMonth(date: .now))
            draft.kind = .receivable
            draft.icon = PaymentDraft.defaultIcon(for: .receivable)
            _draft = State(initialValue: draft)
        case .createFromImport(let parsed):
            _draft = State(initialValue: parsed.makeDraft(today: YearMonth(date: .now)))
        case .edit(let payment): _draft = State(initialValue: payment.makeDraft())
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if case .createFromImport(let parsed) = mode {
                    Section {
                        InfoBanner(text: parsed.bannerText, onClose: nil)
                            .accessibilityIdentifier("importBanner")
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                if !draft.isEditing && draft.kind != .receivable {
                    Section {
                        Picker(L10n.Forms.kind, selection: $draft.kind) {
                            ForEach([PaymentKind.credit, .cash], id: \.self) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                    }
                }

                Section {
                    TextField(L10n.Common.name, text: $draft.name)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: "name")
                    Picker(L10n.Common.currency, selection: $draft.currency) {
                        ForEach(PaymentDraft.currencyOptions) { Text($0.displayName).tag($0) }
                    }
                }
                .listRowBackground(Theme.surface)

                if draft.kind == .credit {
                    Section {
                        numberField(L10n.Forms.installmentCount, text: $draft.installmentCountText, decimal: false)
                        numberField(L10n.Forms.monthlyAmount, text: $draft.monthlyAmountText, decimal: true)
                        MonthPicker(title: L10n.Forms.firstInstallmentMonth, selection: $draft.firstMonth)
                        if !draft.isEditing {
                            numberField(L10n.Forms.prepaidCount, text: $draft.prepaidCountText, decimal: false)
                        }
                    }
                    .listRowBackground(Theme.surface)
                } else {
                    Section {
                        numberField(draft.kind == .receivable ? L10n.Forms.totalReceivable : L10n.Forms.totalDebt, text: $draft.totalDebtText, decimal: true)
                    }
                    .listRowBackground(Theme.surface)
                }

                if let preview = draft.preview {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.Forms.preview(MoneyFormatter.string(PaymentCalculator.total(preview), preview.currency),
                                                    MoneyFormatter.string(PaymentCalculator.remaining(preview), preview.currency)))
                                .font(.subheadline.weight(.semibold))
                            if let last = PaymentCalculator.lastInstallmentMonth(preview) {
                                Text(L10n.Forms.lastInstallment(last.longLabel)).font(.caption).foregroundStyle(Theme.secondaryText)
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

                Section {
                    IconGridPicker(selection: $draft.icon,
                                   emojis: PaymentDraft.icons,
                                   showsBanks: draft.kind == .credit || Bank(icon: draft.icon) != nil,
                                   tint: Theme.kindColor(draft.kind == .receivable ? .credit : draft.kind))
                } header: {
                    Text(L10n.Common.icon)
                }
                .listRowBackground(Theme.surface)

                if draft.isEditing {
                    Section {
                        Button(L10n.Forms.deleteRecord, role: .destructive) { confirmingDelete = true }
                    }
                    .listRowBackground(Theme.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(draft.isEditing ? L10n.Common.edit : (draft.kind == .receivable ? L10n.Forms.newReceivable : L10n.Forms.newPayment))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.save) { save() }
                        .fontWeight(.bold)
                        .disabled(!draft.isValid)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L10n.Common.done) { focusedField = nil }
                        .fontWeight(.semibold)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: draft.icon) { _, icon in
                focusedField = nil
                // Banka seçilince ad boşsa banka adıyla doldur; kullanıcı sonra değiştirebilir.
                if let bank = Bank(icon: icon), draft.trimmedName.isEmpty {
                    draft.name = bank.name
                }
            }
            .onChange(of: draft.currency) { focusedField = nil }
            .onChange(of: draft.firstMonth) { focusedField = nil }
            .onChange(of: draft.kind) { _, newKind in
                focusedField = nil
                if PaymentKind.allCases.map(PaymentDraft.defaultIcon(for:)).contains(draft.icon) {
                    draft.icon = PaymentDraft.defaultIcon(for: newKind)
                }
            }
            .confirmationDialog(L10n.Forms.deleteConfirmTitle, isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button(L10n.Common.delete, role: .destructive) {
                    onDeleteRequested?()
                    dismiss()
                }
                Button(L10n.Common.dismiss, role: .cancel) {}
            } message: {
                Text(L10n.Forms.deleteConfirmMessage)
            }
        }
        .tint(Theme.accent)
        .appColorScheme()
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
        case .create, .createReceivable, .createFromImport:
            guard let payment = Payment.make(from: draft) else { return }
            context.insert(payment)
        case .edit(let payment):
            guard payment.apply(draft) else { return }
        }
        context.saveQuietly()
        dismiss()
    }
}
