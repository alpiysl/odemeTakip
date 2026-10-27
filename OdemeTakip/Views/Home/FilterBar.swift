import SwiftUI

enum HomeFilter: String, CaseIterable, Identifiable {
    case all = "Tümü"
    case credit = "Kredi"
    case cash = "Elden"

    var id: String { rawValue }

    func includes(_ kind: PaymentKind) -> Bool {
        switch self {
        case .all: true
        case .credit: kind == .credit
        case .cash: kind == .cash
        }
    }
}

struct FilterBar<Option>: View
where Option: CaseIterable & Identifiable & Hashable & RawRepresentable,
      Option.RawValue == String, Option.AllCases: RandomAccessCollection {
    @Binding var selection: Option
    var gradient: LinearGradient = Theme.gradient

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Option.allCases) { filter in
                Button {
                    selection = filter
                } label: {
                    Text(filter.rawValue)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background {
                            if selection == filter {
                                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(gradient)
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
