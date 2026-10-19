import SwiftUI

struct MonthPicker: View {
    let title: String
    @Binding var selection: YearMonth

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 4) {
                Picker("Ay", selection: monthBinding) {
                    ForEach(1...12, id: \.self) { Text(TurkishMonths.names[$0 - 1]).tag($0) }
                }
                Picker("Yıl", selection: yearBinding) {
                    ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    private var years: [Int] {
        let current = YearMonth(date: .now).year
        return Array(min(current - 10, selection.year)...max(current + 5, selection.year))
    }

    private var monthBinding: Binding<Int> {
        Binding(get: { selection.month },
                set: { selection = YearMonth(year: selection.year, month: $0) })
    }

    private var yearBinding: Binding<Int> {
        Binding(get: { selection.year },
                set: { selection = YearMonth(year: $0, month: selection.month) })
    }
}
