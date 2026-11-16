import UIKit

/// `ReportData`'yı A4 PDF'e çizer. Önce sayfalara yerleştirir, sonra çizer; böylece "Sayfa x/y" bilinir.
enum ReportPDFRenderer {
    static let pageSize = CGSize(width: 595, height: 842)
    private static let margin: CGFloat = 40
    private static let top: CGFloat = 64
    private static let bottom: CGFloat = 800

    // MARK: Public

    static func render(_ data: ReportData) -> Data {
        let pages = paginate(items(for: data))
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: format(data))
        return renderer.pdfData { context in
            for (index, page) in pages.enumerated() {
                context.beginPage()
                drawChrome(data, page: index + 1, of: pages.count)
                for placed in page { draw(placed.item, at: placed.y) }
            }
        }
    }

    /// PDF'i `directory` içine yazar ve dosya adresini döner.
    static func write(_ data: ReportData, to directory: URL, date: Date = .now) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: fileName(date: date))
        try render(data).write(to: url, options: .atomic)
        return url
    }

    static func fileName(date: Date, calendar: Calendar = AppCalendar.calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        let stamp = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        return "\(L10n.Documents.fileNamePrefixReport)-\(stamp).pdf"
    }

    // MARK: Layout

    private enum Item {
        case title(String, String)
        case section(String)
        case blockHeader(String, String)
        case line(ReportLine)
        case tableHeader([String])
        case row(ReportRow, columnCount: Int)
        case spacer(CGFloat)

        var height: CGFloat {
            switch self {
            case .title: 54
            case .section: 34
            case .blockHeader: 40
            case .line: 18
            case .tableHeader: 22
            case .row: 18
            case .spacer(let h): h
            }
        }
    }

    private struct Placed {
        var item: Item
        var y: CGFloat
    }

    private static func items(for data: ReportData) -> [Item] {
        var items: [Item] = [.title(data.title, [data.generatedText, data.rangeText].compactMap { $0 }.joined(separator: "  ·  "))]
        if !data.summary.isEmpty {
            items.append(.section(L10n.Documents.sectionSummary))
            items += data.summary.map(Item.line)
        }
        if !data.debts.isEmpty {
            items.append(.section(L10n.Documents.sectionDebts))
            for block in data.debts { items += blockItems(block) }
        }
        if !data.receivables.isEmpty {
            items.append(.section(L10n.Documents.sectionReceivables))
            for block in data.receivables { items += blockItems(block) }
        }
        if !data.savings.isEmpty {
            items.append(.section(L10n.Documents.sectionSavings))
            items += data.savings.map(Item.line)
        }
        return items
    }

    private static func blockItems(_ block: ReportBlock) -> [Item] {
        var items: [Item] = [.blockHeader(block.title, block.subtitle)]
        items += block.facts.map(Item.line)
        if !block.rows.isEmpty {
            items.append(.spacer(6))
            items.append(.tableHeader(block.columns))
            items += block.rows.map { .row($0, columnCount: block.columns.count) }
        }
        items.append(.spacer(12))
        return items
    }

    private static func paginate(_ items: [Item]) -> [[Placed]] {
        var pages: [[Placed]] = [[]]
        var y = top
        var lastHeader: Item?
        for item in items {
            if case .tableHeader = item { lastHeader = item }
            if case .blockHeader = item { lastHeader = nil }
            // Başlık sayfa sonunda yalnız kalmasın.
            let keepWithNext: CGFloat = switch item {
            case .section, .blockHeader, .tableHeader: 40
            default: 0
            }
            if y + item.height + keepWithNext > bottom {
                pages.append([])
                y = top
                // Bölünen tablonun başlığını yeni sayfada tekrarla.
                if case .row = item, let header = lastHeader {
                    pages[pages.count - 1].append(Placed(item: header, y: y))
                    y += header.height
                }
            }
            if case .spacer = item, y == top { continue }
            pages[pages.count - 1].append(Placed(item: item, y: y))
            y += item.height
        }
        return pages
    }

    // MARK: Drawing

    private static let ink = UIColor(white: 0.08, alpha: 1)
    private static let muted = UIColor(white: 0.45, alpha: 1)
    private static let rule = UIColor(white: 0.86, alpha: 1)
    private static let accent = UIColor(red: 0xC4 / 255, green: 0x53 / 255, blue: 0x2D / 255, alpha: 1)
    private static let paidColor = UIColor(red: 0x1F / 255, green: 0x9D / 255, blue: 0x45 / 255, alpha: 1)

    private static var contentWidth: CGFloat { pageSize.width - margin * 2 }

    private static func format(_ data: ReportData) -> UIGraphicsPDFRendererFormat {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: data.title,
            kCGPDFContextCreator as String: L10n.Settings.appTitle,
        ]
        return format
    }

    private static func drawChrome(_ data: ReportData, page: Int, of count: Int) {
        let small = UIFont.systemFont(ofSize: 9)
        text(L10n.Settings.appTitle, CGRect(x: margin, y: 24, width: contentWidth / 2, height: 14), small, muted)
        text(data.generatedText, CGRect(x: margin + contentWidth / 2, y: 24, width: contentWidth / 2, height: 14),
             small, muted, align: .right)
        fill(rule, CGRect(x: margin, y: 42, width: contentWidth, height: 0.5))
        text(L10n.Documents.page(page, count), CGRect(x: margin, y: pageSize.height - 30, width: contentWidth, height: 14),
             small, muted, align: .center)
    }

    private static func draw(_ item: Item, at y: CGFloat) {
        switch item {
        case let .title(title, subtitle):
            text(title, CGRect(x: margin, y: y, width: contentWidth, height: 28), .systemFont(ofSize: 22, weight: .bold), ink)
            text(subtitle, CGRect(x: margin, y: y + 30, width: contentWidth, height: 16), .systemFont(ofSize: 11), muted)
        case let .section(title):
            text(title.uppercased(with: L10n.locale), CGRect(x: margin, y: y + 10, width: contentWidth, height: 16),
                 .systemFont(ofSize: 11, weight: .bold), accent)
            fill(accent, CGRect(x: margin, y: y + 28, width: contentWidth, height: 1))
        case let .blockHeader(title, subtitle):
            text(title, CGRect(x: margin, y: y + 6, width: contentWidth, height: 18), .systemFont(ofSize: 14, weight: .semibold), ink)
            text(subtitle, CGRect(x: margin, y: y + 24, width: contentWidth, height: 14), .systemFont(ofSize: 10), muted)
        case let .line(line):
            let font = UIFont.systemFont(ofSize: 11)
            text(line.label, CGRect(x: margin, y: y + 2, width: contentWidth * 0.6, height: 15), font, muted)
            text(line.value, CGRect(x: margin + contentWidth * 0.4, y: y + 2, width: contentWidth * 0.6, height: 15),
                 .monospacedDigitSystemFont(ofSize: 11, weight: .semibold), ink, align: .right)
        case let .tableHeader(columns):
            fill(UIColor(white: 0.95, alpha: 1), CGRect(x: margin, y: y, width: contentWidth, height: 20))
            drawCells(columns, y: y + 4, font: .systemFont(ofSize: 9, weight: .bold), colors: Array(repeating: muted, count: columns.count))
        case let .row(row, count):
            var colors = Array(repeating: ink, count: count)
            if row.isPaid, count == 4 { colors[3] = paidColor }
            drawCells(row.cells, y: y + 2, font: .monospacedDigitSystemFont(ofSize: 10, weight: .regular), colors: colors)
            fill(rule, CGRect(x: margin, y: y + 17.5, width: contentWidth, height: 0.5))
        case .spacer:
            break
        }
    }

    /// 4 sütun: No | Ay | Tutar | Durum; 2 sütun: Tarih | Tutar.
    private static func drawCells(_ cells: [String], y: CGFloat, font: UIFont, colors: [UIColor]) {
        let layout: [(CGFloat, CGFloat, NSTextAlignment)] = cells.count == 4
            ? [(0, 0.1, .left), (0.1, 0.4, .left), (0.5, 0.25, .right), (0.78, 0.22, .left)]
            : [(0, 0.6, .left), (0.6, 0.4, .right)]
        for (index, cell) in cells.enumerated() where index < layout.count {
            let (start, width, align) = layout[index]
            let rect = CGRect(x: margin + 6 + contentWidth * start, y: y,
                              width: contentWidth * width - 12, height: 14)
            text(cell, rect, font, colors[min(index, colors.count - 1)], align: align)
        }
    }

    private static func text(_ string: String, _ rect: CGRect, _ font: UIFont, _ color: UIColor,
                             align: NSTextAlignment = .left) {
        let style = NSMutableParagraphStyle()
        style.alignment = align
        style.lineBreakMode = .byTruncatingTail
        NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
            .draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
    }

    private static func fill(_ color: UIColor, _ rect: CGRect) {
        color.setFill()
        UIRectFill(rect)
    }
}
