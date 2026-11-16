import SwiftUI

/// Açılışta gösterilen ana ekran.
enum HomeMode: String, CaseIterable, Identifiable {
    case debt
    case savings

    static let storageKey = "homeMode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .debt: L10n.Settings.modeDebtTitle
        case .savings: L10n.Settings.modeSavingsTitle
        }
    }

    var shortTitle: String {
        switch self {
        case .debt: L10n.Settings.modeDebtShort
        case .savings: L10n.Settings.modeSavingsShort
        }
    }

    var fill: Color {
        switch self {
        case .debt: Theme.debtFill
        case .savings: Theme.savingsFill
        }
    }
}

/// Başlık: uygulama adı + Borç | Birikim anahtarı.
struct HomeHeader: View {
    @Binding var mode: HomeMode
    var onSettings: () -> Void = {}
    var onReport: () -> Void = {}

    var body: some View {
        // Sığmazsa başlık üstte, anahtar ve ayar altta.
        ViewThatFits(in: .horizontal) {
            HStack {
                title
                Spacer(minLength: 8)
                controls
            }
            VStack(alignment: .leading, spacing: 8) {
                title
                HStack {
                    controls
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.top, 4)
        // Arayüz kontrolleri en büyük erişilebilirlik boyutlarında taşmasın.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var title: some View {
        Text(L10n.Settings.appTitle)
            .font(.title3.weight(.bold))
            .lineLimit(1)
    }

    private var controls: some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(HomeMode.allCases) { option in
                    Button {
                        mode = option
                    } label: {
                        Text(option.shortTitle)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background {
                                if mode == option {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous).fill(option.fill)
                                }
                            }
                            .foregroundStyle(mode == option ? Color.white : Theme.unselectedText)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("mode-\(option.rawValue)")
                    .accessibilityAddTraits(mode == option ? .isSelected : [])
                }
            }
            .padding(3)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .sensoryFeedback(.selection, trigger: mode)
            Button(action: onReport) {
                Image(systemName: "doc.text")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(L10n.Documents.createReport)
            .accessibilityIdentifier("reportButton")
            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(L10n.Settings.title)
        }
    }
}

/// Ayarlar: açılış ekranı ve görünüm seçimi. Değişince 2 sn'lik mesaj.
struct SettingsView: View {
    @AppStorage(HomeMode.storageKey) private var landingRaw = HomeMode.debt.rawValue
    @AppStorage(AppAppearance.storageKey) private var appearanceRaw = AppAppearance.dark.rawValue
    @Environment(\.dismiss) private var dismiss
    @State private var toastText: String?
    @State private var toastTask: Task<Void, Never>?

    private var landing: Binding<HomeMode> {
        Binding(
            get: { HomeMode(rawValue: landingRaw) ?? .debt },
            set: { newMode in
                guard newMode.rawValue != landingRaw else { return }
                landingRaw = newMode.rawValue
                showToast(L10n.Settings.landingToast(newMode.title))
            })
    }

    private var appearance: Binding<AppAppearance> {
        Binding(
            get: { AppAppearance(rawValue: appearanceRaw) ?? .dark },
            set: { newValue in
                guard newValue.rawValue != appearanceRaw else { return }
                withAnimation(.easeInOut(duration: 0.25)) { appearanceRaw = newValue.rawValue }
                showToast(L10n.Settings.appearanceToast(newValue.title))
            })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(L10n.Settings.landingTitle, selection: landing) {
                        ForEach(HomeMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                } header: {
                    Text(L10n.Settings.landingTitle)
                } footer: {
                    Text(L10n.Settings.landingFooter)
                }

                Section {
                    Picker(L10n.Settings.appearanceTitle, selection: appearance) {
                        ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("appearancePicker")
                } header: {
                    Text(L10n.Settings.appearanceTitle)
                } footer: {
                    Text(L10n.Settings.appearanceFooter)
                }

                Section {
                    LabeledContent(L10n.Settings.sourceCurrencies, value: L10n.Settings.sourceCurrenciesValue)
                    LabeledContent(L10n.Settings.sourceGold, value: L10n.Settings.sourceGoldValue)
                } header: {
                    Text(L10n.Settings.sourcesTitle)
                } footer: {
                    Text(L10n.Settings.sourcesFooter)
                }
                .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(L10n.Settings.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
            }
        }
        .overlay(alignment: .top) {
            if let toastText {
                ToastView(text: toastText)
                    .padding(.top, 8)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .tint(Theme.accent)
        .appColorScheme()
        .presentationDetents([.medium, .large])
    }

    /// 2 sn görünen, yavaşça belirip kaybolan bilgi mesajı.
    private func showToast(_ text: String) {
        toastTask?.cancel()
        toastTask = Task { @MainActor in
            withAnimation(.easeInOut(duration: 0.35)) { toastText = text }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.35)) { toastText = nil }
        }
    }
}

/// Kısa bilgi mesajı (üstte, fade in/out).
struct ToastView: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Theme.toastBackground.opacity(0.97), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.toastBorder))
            .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
            .accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier("toast")
    }
}

/// "Net varlık (− borç)" satırı; hesaplanamıyorsa görünmez.
struct NetWorthRow: View {
    let net: Decimal?

    var body: some View {
        if let net {
            let label = Text(L10n.Settings.netWorth).foregroundStyle(Theme.secondaryText)
            let value = Text(MoneyFormatter.signed(net)).fontWeight(.bold).monospacedDigit().lineLimit(1)
            ViewThatFits(in: .horizontal) {
                HStack {
                    label.lineLimit(1)
                    Spacer()
                    value
                }
                VStack(alignment: .leading, spacing: 2) {
                    label
                    value.minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.footnote)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("netWorth")
        }
    }
}

/// İlk açılışta ana ekran seçimi.
struct OnboardingView: View {
    let onChoose: (HomeMode) -> Void
    @State private var selection: HomeMode = .debt

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.Settings.welcome).font(.largeTitle.weight(.heavy))
                Text(L10n.Settings.welcomeMessage)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.bottom, 10)
                card(.debt, emoji: "💳", detail: L10n.Settings.onboardingDebtDetail)
                card(.savings, emoji: "🌱", detail: L10n.Settings.onboardingSavingsDetail)
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 70)

            Button {
                onChoose(selection)
            } label: {
                Text(L10n.Settings.continueButton)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(selection.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
    }

    private func card(_ mode: HomeMode, emoji: String, detail: String) -> some View {
        Button {
            selection = mode
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(emoji).font(.largeTitle)
                Text(mode.title).font(.title3.weight(.bold))
                Text(detail).font(.footnote).foregroundStyle(Theme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Theme.footer, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(selection == mode ? Theme.accent : Theme.cardBorder, lineWidth: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboarding-\(mode.rawValue)")
        .accessibilityAddTraits(selection == mode ? .isSelected : [])
    }
}
