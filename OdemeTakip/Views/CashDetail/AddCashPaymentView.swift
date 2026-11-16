import SwiftData
import SwiftUI

/// Elden ödeme / tahsilat ekleme; `editing` verilirse o kaydı düzeltme ya da silme.
struct AddCashPaymentView: View {
    let payment: Payment
    var editing: CashPayment? = nil

    @Environment(RateStore.self) private var rateStore
    private var rates: ExchangeRates? { rateStore.rates }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CashPaymentDraft
    @State private var confirmingDelete = false
    @FocusState private var amountFocused: Bool

    init(payment: Payment, editing: CashPayment? = nil) {
        self.payment = payment
        self.editing = editing
        let remaining = PaymentCalculator.remaining(payment.snapshot)
        let receivable = payment.kind == .receivable
        if let editing {
            _draft = State(initialValue: CashPaymentDraft(
                editing: editing.amount, date: editing.date, remaining: remaining,
                currency: payment.currency, isReceivable: receivable))
        } else {
            _draft = State(initialValue: CashPaymentDraft(
                remaining: remaining, currency: payment.currency, isReceivable: receivable))
        }
    }

    private var title: String {
        switch (editing != nil, draft.isReceivable) {
        case (true, true): L10n.Debt.editCollectionTitle
        case (true, false): L10n.Debt.editPaymentTitle
        case (false, true): L10n.Debt.addCollectionTitle
        case (false, false): L10n.Debt.addPaymentTitle
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(L10n.Common.amount) {
                        TextField("0", text: $draft.amountText)
                            .keyboardType(.decimalPad)
                            .onChange(of: draft.amountText) { _, text in
                                let clean = AmountParser.sanitized(text)
                                if clean != text { draft.amountText = clean }
                            }
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .focused($amountFocused)
                    }
                    Button {
                        draft.amountText = AmountParser.editingText(draft.remaining)
                    } label: {
                        Label(draft.isReceivable ? L10n.Debt.payAllReceivable : L10n.Debt.payAllDebt,
                              systemImage: "equal.circle")
                    }
                    DatePicker(L10n.Common.date, selection: $draft.date, displayedComponents: .date)
                        .onChange(of: draft.date) { amountFocused = false }
                        .environment(\.locale, L10n.locale)
                } footer: {
                    if let message = draft.validationMessage {
                        Text(message).foregroundStyle(Theme.cash)
                    } else {
                        Text(remainingFooter)
                    }
                }
                .listRowBackground(Theme.surface)

                if editing != nil {
                    Section {
                        Label(L10n.Debt.editNote, systemImage: "doc.text.magnifyingglass")
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryText)
                            .accessibilityIdentifier("editNote")
                    }
                    .listRowBackground(Color.clear)

                    Section {
                        Button(draft.isReceivable ? L10n.Debt.deleteCollection : L10n.Debt.deletePayment,
                               role: .destructive) { confirmingDelete = true }
                    }
                    .listRowBackground(Theme.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.save) { save() }
                        .fontWeight(.bold)
                        .disabled(draft.amount == nil)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L10n.Common.done) { amountFocused = false }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { if editing == nil { amountFocused = true } }
            .confirmationDialog(L10n.Debt.deleteEntryConfirm, isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button(L10n.Common.delete, role: .destructive) { delete() }
                Button(L10n.Common.dismiss, role: .cancel) {}
            }
        }
        .tint(Theme.accent)
        .appColorScheme()
        .presentationDetents([.medium, .large])
    }

    /// "Kalan: $2.400 (≈ ₺96.000)"
    private var remainingFooter: String {
        let remaining = MoneyFormatter.string(draft.remaining, draft.currency)
        guard let lira = FooterTotalsView.Line.liraEquivalent(draft.remaining, draft.currency, rates: rates) else {
            return L10n.Debt.remainingFooter(remaining)
        }
        return L10n.Debt.remainingFooter(remaining, lira: lira.value)
    }

    private func save() {
        guard let amount = draft.amount else { return }
        if let editing {
            payment.updateCashPayment(editing, amount: amount, date: draft.date)
        } else {
            payment.addCashPayment(amount: amount, date: draft.date)
        }
        context.saveQuietly()
        dismiss()
    }

    private func delete() {
        guard let editing else { return }
        payment.removeCashPayment(editing)
        context.saveQuietly()
        dismiss()
    }
}
