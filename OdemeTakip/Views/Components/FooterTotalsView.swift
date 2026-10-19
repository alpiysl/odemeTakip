import SwiftUI

struct FooterTotalsView: View {
    struct Line {
        let title: String
        let value: String
        var color: Color? = nil
    }

    let lines: [Line]
    let resultTitle: String
    let resultValue: String

    var body: some View {
        VStack(spacing: 3) {
            ForEach(lines.indices, id: \.self) { i in
                HStack {
                    Text(lines[i].title)
                    Spacer()
                    Text(lines[i].value).foregroundStyle(lines[i].color ?? Theme.secondaryText)
                }
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
            }
            HStack {
                Text(resultTitle)
                Spacer()
                Text(resultValue)
            }
            .font(.headline.weight(.heavy))
            .padding(.top, 4)
        }
        .monospacedDigit()
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(Theme.footer)
        .overlay(alignment: .top) { Color(hex: 0x24242C).frame(height: 1) }
    }
}
