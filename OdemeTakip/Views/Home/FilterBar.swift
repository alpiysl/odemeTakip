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

struct FilterBar: View {
    @Binding var selection: HomeFilter

    var body: some View {
        HStack(spacing: 0) {
            ForEach(HomeFilter.allCases) { filter in
                Button {
                    selection = filter
                } label: {
                    Text(filter.rawValue)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background {
                            if selection == filter {
                                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.gradient)
                            }
                        }
                        .foregroundStyle(selection == filter ? Color.white : Color.white.opacity(0.6))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .sensoryFeedback(.selection, trigger: selection)
    }
}
