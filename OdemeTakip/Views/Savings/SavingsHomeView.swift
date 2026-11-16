import SwiftUI

enum SavingsFilter: String, FilterOption {
    case all
    case assets
    case receivables

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: L10n.Common.all
        case .assets: L10n.Savings.filterAssets
        case .receivables: L10n.Savings.filterReceivables
        }
    }
}

struct SavingsHomeView: View {
    let assets: [Asset]
    let receivables: [Payment]
    let summary: WealthSummary
    let rates: ExchangeRates?
    @Binding var mode: HomeMode
    var onSettings: () -> Void = {}
    var onReport: () -> Void = {}

    @State private var filter: SavingsFilter = .all
    @Environment(\.isCompactHeader) private var compact
    @ScaledMetric(relativeTo: .largeTitle) private var totalSize: CGFloat = 36
    @ScaledMetric(relativeTo: .largeTitle) private var compactTotalSize: CGFloat = 28
    @State private var addingAsset = false
    @State private var addingReceivable = false

    var body: some View {
        let openReceivables = receivables.filter { !PaymentCalculator.isCompleted($0.snapshot) }
        let closedReceivables = receivables.filter { PaymentCalculator.isCompleted($0.snapshot) }
        let showAssets = filter != .receivables
        let showReceivables = filter != .assets

        PinnedLayout {
            HomeHeader(mode: $mode, onSettings: onSettings, onReport: onReport)
            summaryCard
            NetWorthRow(net: summary.net)
            RateBar(rates: rates)
            if !(assets.isEmpty && receivables.isEmpty) {
                FilterBar(selection: $filter, gradient: Theme.savingsGradient)
            }
        } content: {
                    if assets.isEmpty && receivables.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 0) {
                            if showAssets {
                                ForEach(assets) { asset in
                                    NavigationLink {
                                        AssetDetailView(asset: asset)
                                    } label: {
                                        AssetRowView(asset: asset, rates: rates)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            if showReceivables {
                                ForEach(openReceivables) { receivableRow($0) }
                            }
                        }
                        if showReceivables && !closedReceivables.isEmpty {
                            Text(L10n.Common.completedSection)
                                .font(.caption.weight(.semibold))
                                .textCase(.uppercase)
                                .foregroundStyle(Theme.secondaryText)
                                .padding(.top, 8)
                            LazyVStack(spacing: 0) {
                                ForEach(closedReceivables) { receivableRow($0).opacity(0.5) }
                            }
                        }
                    }
        }
        .background(Theme.background.ignoresSafeArea())
        .addBar { addMenu }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $addingAsset) {
            AssetFormView(mode: .create)
        }
        .sheet(isPresented: $addingReceivable) {
            PaymentFormView(mode: .createReceivable)
        }
    }

    private var summaryCard: some View {
        let assetTotals = WealthCalculator.assetTotals(assets.map(\.snapshot))
        let receivableTotals = PaymentCalculator.totals(receivables.map(\.snapshot)).receivable
        let combined = assetTotals.merging(receivableTotals, uniquingKeysWith: +)
        let total: String = if let savings = summary.savings, let receivable = summary.receivable {
            MoneyFormatter.string(savings + receivable, .TRY)
        } else {
            MoneyFormatter.joined(combined)
        }

        return VStack(alignment: .leading, spacing: 2) {
            Text(L10n.Savings.totalWealth).font(.caption).opacity(0.85)
            Text(total)
                .font(.system(size: compact ? compactTotalSize : totalSize, weight: .heavy))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) { legends(assetTotals, receivableTotals) }
                VStack(alignment: .leading, spacing: 4) { legends(assetTotals, receivableTotals) }
            }
            .font(.caption)
            .padding(.top, compact ? 4 : 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compact ? 12 : 18)
        .background(Theme.savingsGradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private func legends(_ assetTotals: [Currency: Decimal], _ receivableTotals: [Currency: Decimal]) -> some View {
        legend(color: .white, title: L10n.Savings.legendSavings,
               value: summary.savings.map { MoneyFormatter.string($0, .TRY) } ?? MoneyFormatter.joined(assetTotals))
        legend(color: Theme.credit, title: L10n.Savings.legendReceivables,
               value: summary.receivable.map { MoneyFormatter.string($0, .TRY) } ?? MoneyFormatter.joined(receivableTotals))
    }

    private func legend(color: Color, title: String, value: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title)
            Text(value).fontWeight(.bold)
        }
    }

    private func receivableRow(_ payment: Payment) -> some View {
        NavigationLink {
            CashDetailView(payment: payment)
        } label: {
            PaymentRowView(payment: payment, rates: rates)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        EmptyStateView(systemImage: "leaf",
                       title: L10n.Savings.emptyTitle,
                       message: L10n.Savings.emptyMessage)
    }

    private var addMenu: some View {
        Menu {
            Button(L10n.Savings.addAsset, systemImage: "leaf") { addingAsset = true }
            Button(L10n.Savings.addReceivable, systemImage: "person.crop.circle.badge.plus") { addingReceivable = true }
        } label: {
            AddBarLabel(title: L10n.Savings.newRecord, gradient: Theme.savingsGradient)
        }
        .accessibilityLabel(L10n.Savings.newRecord)
    }
}

struct AssetRowView: View {
    let asset: Asset
    let rates: ExchangeRates?

    var body: some View {
        let snapshot = asset.snapshot
        let lira = CurrencyConverter.toTRY([snapshot.unit: snapshot.quantity], rates: rates)
        HStack(spacing: 12) {
            Text(asset.icon)
                .font(.title3)
                .frame(width: 40, height: 40)
                .background((snapshot.unit.isGold ? Theme.cash : Theme.paid).opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(Self.subtitle(snapshot)).font(.caption).foregroundStyle(Theme.secondaryText).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(lira.map { MoneyFormatter.string($0, .TRY) } ?? MoneyFormatter.string(snapshot.quantity, snapshot.unit))
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .layoutPriority(1)
            Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(Theme.tertiaryText)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Theme.divider.frame(height: 1) }
    }

    static func subtitle(_ s: AssetSnapshot) -> String {
        let quantity = MoneyFormatter.string(s.quantity, s.unit)
        return s.unit.isGold ? L10n.Savings.goldSubtitle(quantity, s.unit.displayName) : quantity
    }
}
