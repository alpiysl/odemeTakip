import SwiftUI

enum HomeFilter: String, FilterOption {
    case all
    case credit
    case cash

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: L10n.Common.all
        case .credit: L10n.Home.filterCredit
        case .cash: L10n.Home.filterCash
        }
    }

    func includes(_ kind: PaymentKind) -> Bool {
        switch self {
        case .all: true
        case .credit: kind == .credit
        case .cash: kind == .cash
        }
    }
}

/// Filtre seçenekleri: görünen ad `title`, metin tablosundan gelir.
protocol FilterOption: CaseIterable, Identifiable, Hashable where AllCases: RandomAccessCollection {
    var title: String { get }
}

struct FilterBar<Option: FilterOption>: View {
    @Binding var selection: Option
    var fill: Color = Theme.debtFill

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Option.allCases) { filter in
                Button {
                    selection = filter
                } label: {
                    Text(filter.title)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background {
                            if selection == filter {
                                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(fill)
                            }
                        }
                        .foregroundStyle(selection == filter ? Color.white : Theme.unselectedText)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == filter ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .sensoryFeedback(.selection, trigger: selection)
    }
}
