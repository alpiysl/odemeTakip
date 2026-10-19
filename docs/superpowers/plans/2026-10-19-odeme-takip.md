# Ödeme Takip Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tek kullanıcılı, koyu temalı, kredi ve elden borçları takip eden, her ayın 1'inde yerel bildirim gönderen iOS uygulaması.

**Architecture:** Saf Swift mantık katmanı (`Logic/`, değer tipleri, SwiftUI/SwiftData'dan bağımsız, Swift Testing ile test edilir) + SwiftData modelleri (`Models/`, `snapshot` ile mantık katmanına değer kopyası verir) + SwiftUI ekranları (`Views/`). Bildirimler `UNUserNotificationCenter` ile yerel; içerik saf `NotificationContentBuilder` tarafından üretilir.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, UserNotifications, Swift Testing, XcodeGen, Xcode 27.1, iOS 17+.

**Spec:** `docs/superpowers/specs/2026-10-19-odeme-takip-design.md`

## Global Constraints

- iOS deployment target `17.0`, sadece iPhone (`TARGETED_DEVICE_FAMILY = 1`), sadece portre.
- Bundle ID sabit: `com.alpiysl.odemetakip`. Görünen ad: `Ödeme Takip`.
- Harici paket bağımlılığı yok, ağ erişimi yok.
- Uygulama kodunda `fatalError`, force unwrap (`!`), `try!` YOK. (Sadece `scripts/` altındaki geliştirici betikleri hariç.)
- Tutarlar her yerde `Decimal`. Para birimleri asla birbirine toplanmaz.
- Para birimleri: `TRY` (₺), `USD` ($), `EUR` (€). Biçim `tr_TR`: `₺15.000`, `€1.234,50`.
- Takvim: `AppCalendar.calendar` (gregorian, `tr_TR`, cihaz saat dilimi).
- Renkler: zemin `#0B0B0F`, yüzey `#1C1C22`, ayraç `#1F1F26`, alt panel `#15151B`, halka `#3A3A44`, kredi `#64D2FF`, elden `#FFD60A`, ödendi `#30D158`, gradyan `#5E5CE6 → #BF5AF2`.
- Sadece koyu tema.
- Arayüz metinleri Türkçe.
- Test komutu (her yerde aynı):
  `xcodebuild test -project OdemeTakip.xcodeproj -scheme OdemeTakip -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
- Commit mesajları conventional (`feat:`, `test:`, `chore:`) ve şu satırla biter: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`

## Review Focus

1. Türkçe klavyeyle tutar girişi (`1.500,50`, `15.000`, `15000`, `1500,5`) doğru sayıya çevrilmeli, `1,999` / `abc` / `-5` reddedilmeli → Task 2 `AmountParserTests`.
2. Yıl geçişi: Kasım'da başlayan kredinin Ocak taksiti ve Aralık→Ocak bildirim ayları doğru hesaplanmalı → Task 1 `YearMonthTests`, Task 3 `PaymentCalculatorTests`, Task 4 `NotificationContentBuilderTests`.
3. Düzenlemede taksit sayısı ödenmiş taksitlerin altına / toplam borç ödenen tutarın altına indirilememeli → Task 5 `PaymentDraftTests`.
4. Farklı para birimleri hiçbir toplamda birleşmemeli → Task 3 `totalsNeverMixCurrencies`.
5. Ayın 1'i 09:00'dan önce açılırsa o ayın bildirimi yine planlanmalı; 09:00'dan sonra açılırsa bir sonraki aya geçmeli → Task 4 `triggerMonths*` testleri.

---

## File Structure

```
odemeTakipApp/
  project.yml                          # XcodeGen tanımı
  OdemeTakip.xcodeproj/                # XcodeGen çıktısı (commit edilir)
  scripts/make-icon.swift              # 1024px app icon üretir
  docs/KURULUM.md                      # telefona kurulum talimatı
  OdemeTakip/
    Info.plist                         # XcodeGen üretir
    App/OdemeTakipApp.swift            # @main, container, bildirim delegate
    App/RootView.swift                 # NavigationStack, @Query, bildirim yeniden planlama
    App/Persistence.swift              # ModelContainer kurulumu, saveQuietly, Log
    App/SampleData.swift               # DEBUG örnek veri (-seedSampleData)
    Models/PaymentKind.swift           # PaymentKind, Currency
    Models/Payment.swift               # @Model Payment
    Models/CashPayment.swift           # @Model CashPayment
    Logic/YearMonth.swift              # YearMonth, AppCalendar, TurkishMonths
    Logic/MoneyFormatter.swift         # biçimlendirme
    Logic/AmountParser.swift           # metin → Decimal
    Logic/PaymentSnapshot.swift        # değer kopyası
    Logic/PaymentCalculator.swift      # tüm hesaplar
    Logic/NotificationContentBuilder.swift
    Logic/PaymentDraft.swift           # form doğrulama
    Logic/CashPaymentDraft.swift
    Services/NotificationScheduler.swift
    Theme/Theme.swift
    Views/Components/InfoBanner.swift
    Views/Components/FooterTotalsView.swift
    Views/Home/HomeView.swift
    Views/Home/SummaryCardView.swift
    Views/Home/FilterBar.swift
    Views/Home/PaymentRowView.swift
    Views/Form/PaymentFormView.swift
    Views/Form/MonthPicker.swift
    Views/CreditDetail/CreditDetailView.swift
    Views/CreditDetail/InstallmentRowView.swift
    Views/CashDetail/CashDetailView.swift
    Views/CashDetail/AddCashPaymentView.swift
    Resources/Assets.xcassets/...      # AppIcon, LaunchBackground
  OdemeTakipTests/
    YearMonthTests.swift
    MoneyFormatterTests.swift
    AmountParserTests.swift
    PaymentCalculatorTests.swift
    NotificationContentBuilderTests.swift
    PaymentDraftTests.swift
    PaymentModelTests.swift
```

---

### Task 1: Proje iskeleti + temel tipler (YearMonth, Currency, PaymentKind)

**Files:**
- Create: `project.yml`, `.gitignore` (güncelle), `OdemeTakip/App/OdemeTakipApp.swift` (geçici), `OdemeTakip/Models/PaymentKind.swift`, `OdemeTakip/Logic/YearMonth.swift`, `OdemeTakip/Resources/Assets.xcassets/Contents.json`
- Test: `OdemeTakipTests/YearMonthTests.swift`

**Interfaces:**
- Produces:
  - `enum PaymentKind: String, CaseIterable, Codable, Sendable { case credit, cash; var title: String }`
  - `enum Currency: String, CaseIterable, Codable, Sendable, Comparable, Identifiable { case TRY, USD, EUR; var symbol: String; var displayName: String }`
  - `enum AppCalendar { static var calendar: Calendar }`
  - `enum TurkishMonths { static let names: [String]; static let shortNames: [String]; static func dayMonth(_ date: Date, calendar: Calendar = AppCalendar.calendar) -> String }`
  - `struct YearMonth: Hashable, Comparable, Sendable, Codable { let year: Int; let month: Int; init(year:month:); init(date:calendar:); func adding(months:) -> YearMonth; func months(from:) -> Int; func firstDay(calendar:) -> Date; var name: String; var longLabel: String; var shortLabel: String }`

- [ ] **Step 1: XcodeGen kur (kullanıcı onayı alındıysa)**

Run: `brew install xcodegen && xcodegen --version`
Expected: sürüm numarası yazdırılır.

- [ ] **Step 2: `project.yml` yaz**

```yaml
name: OdemeTakip
options:
  bundleIdPrefix: com.alpiysl
  deploymentTarget:
    iOS: "17.0"
  createIntermediateGroups: true
settings:
  base:
    SWIFT_VERSION: "6.0"
    CODE_SIGN_STYLE: Automatic
    DEVELOPMENT_TEAM: ""
targets:
  OdemeTakip:
    type: application
    platform: iOS
    sources:
      - OdemeTakip
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.alpiysl.odemetakip
        PRODUCT_NAME: OdemeTakip
        TARGETED_DEVICE_FAMILY: "1"
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        MARKETING_VERSION: "1.0"
        CURRENT_PROJECT_VERSION: "1"
    info:
      path: OdemeTakip/Info.plist
      properties:
        CFBundleDisplayName: Ödeme Takip
        CFBundleDevelopmentRegion: tr
        UILaunchScreen:
          UIColorName: LaunchBackground
        UISupportedInterfaceOrientations:
          - UIInterfaceOrientationPortrait
        UIUserInterfaceStyle: Dark
        ITSAppUsesNonExemptEncryption: false
  OdemeTakipTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - OdemeTakipTests
    dependencies:
      - target: OdemeTakip
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.alpiysl.odemetakip.tests
        GENERATE_INFOPLIST_FILE: YES
schemes:
  OdemeTakip:
    build:
      targets:
        OdemeTakip: all
        OdemeTakipTests: [test]
    run:
      config: Release
    test:
      config: Debug
      targets:
        - OdemeTakipTests
```

`.gitignore` içeriği:

```
.superpowers/
build/
DerivedData/
*.xcuserstate
xcuserdata/
```

`OdemeTakip/Resources/Assets.xcassets/Contents.json`:

```json
{ "info" : { "author" : "xcode", "version" : 1 } }
```

Geçici `OdemeTakip/App/OdemeTakipApp.swift` (Task 7'de değişecek):

```swift
import SwiftUI

@main
struct OdemeTakipApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Ödeme Takip")
        }
    }
}
```

- [ ] **Step 3: Failing test yaz — `OdemeTakipTests/YearMonthTests.swift`**

```swift
import Foundation
import Testing
@testable import OdemeTakip

struct YearMonthTests {
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        AppCalendar.calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h)) ?? .distantPast
    }

    @Test func normalizesOverflowingMonths() {
        #expect(YearMonth(year: 2026, month: 13) == YearMonth(year: 2027, month: 1))
        #expect(YearMonth(year: 2026, month: 0) == YearMonth(year: 2025, month: 12))
    }

    @Test func addingMonthsCrossesYearBoundary() {
        let nov = YearMonth(year: 2026, month: 11)
        #expect(nov.adding(months: 2) == YearMonth(year: 2027, month: 1))
        #expect(nov.adding(months: -11) == YearMonth(year: 2025, month: 12))
    }

    @Test func monthsBetween() {
        let a = YearMonth(year: 2025, month: 9)
        let b = YearMonth(year: 2026, month: 10)
        #expect(b.months(from: a) == 13)
        #expect(a.months(from: b) == -13)
    }

    @Test func comparesChronologically() {
        #expect(YearMonth(year: 2025, month: 12) < YearMonth(year: 2026, month: 1))
        #expect(!(YearMonth(year: 2026, month: 2) < YearMonth(year: 2026, month: 1)))
    }

    @Test func initFromDate() {
        #expect(YearMonth(date: date(2026, 10, 19)) == YearMonth(year: 2026, month: 10))
    }

    @Test func turkishLabels() {
        #expect(YearMonth(year: 2026, month: 10).longLabel == "Ekim 2026")
        #expect(YearMonth(year: 2025, month: 9).shortLabel == "Eyl 2025")
        #expect(YearMonth(year: 2026, month: 11).name == "Kasım")
        #expect(TurkishMonths.dayMonth(date(2026, 10, 5)) == "5 Eki")
    }

    @Test func firstDayIsFirstOfMonth() {
        let first = YearMonth(year: 2026, month: 2).firstDay(calendar: AppCalendar.calendar)
        let comps = AppCalendar.calendar.dateComponents([.year, .month, .day], from: first)
        #expect(comps.year == 2026 && comps.month == 2 && comps.day == 1)
    }

    @Test func currencyOrderAndSymbols() {
        #expect(Currency.allCases.sorted() == [.TRY, .USD, .EUR])
        #expect(Currency.TRY.symbol == "₺")
        #expect(Currency.USD.symbol == "$")
        #expect(Currency.EUR.symbol == "€")
        #expect(PaymentKind.credit.title == "Kredi")
        #expect(PaymentKind.cash.title == "Elden")
    }
}
```

- [ ] **Step 4: Projeyi üret, testin derlenmediğini gör**

Run: `xcodegen generate && xcodebuild test -project OdemeTakip.xcodeproj -scheme OdemeTakip -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: FAIL — `cannot find 'YearMonth' in scope`.

- [ ] **Step 5: `OdemeTakip/Models/PaymentKind.swift` yaz**

```swift
import Foundation

enum PaymentKind: String, CaseIterable, Codable, Sendable {
    case credit
    case cash

    var title: String {
        switch self {
        case .credit: "Kredi"
        case .cash: "Elden"
        }
    }
}

enum Currency: String, CaseIterable, Codable, Sendable, Comparable, Identifiable {
    case TRY
    case USD
    case EUR

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .TRY: "₺"
        case .USD: "$"
        case .EUR: "€"
        }
    }

    var displayName: String {
        switch self {
        case .TRY: "₺ TL"
        case .USD: "$ USD"
        case .EUR: "€ EUR"
        }
    }

    private var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    static func < (lhs: Currency, rhs: Currency) -> Bool { lhs.order < rhs.order }
}
```

- [ ] **Step 6: `OdemeTakip/Logic/YearMonth.swift` yaz**

```swift
import Foundation

enum AppCalendar {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "tr_TR")
        calendar.timeZone = .current
        return calendar
    }
}

enum TurkishMonths {
    static let names = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
                        "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]
    static let shortNames = ["Oca", "Şub", "Mar", "Nis", "May", "Haz",
                             "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"]

    static func dayMonth(_ date: Date, calendar: Calendar = AppCalendar.calendar) -> String {
        let comps = calendar.dateComponents([.day, .month], from: date)
        let day = comps.day ?? 1
        let month = min(max((comps.month ?? 1) - 1, 0), 11)
        return "\(day) \(shortNames[month])"
    }
}

struct YearMonth: Hashable, Comparable, Sendable, Codable {
    let year: Int
    /// 1...12
    let month: Int

    init(year: Int, month: Int) {
        let total = year * 12 + (month - 1)
        let normalizedYear = Int((Double(total) / 12).rounded(.down))
        self.year = normalizedYear
        self.month = total - normalizedYear * 12 + 1
    }

    init(date: Date, calendar: Calendar = AppCalendar.calendar) {
        let comps = calendar.dateComponents([.year, .month], from: date)
        self.init(year: comps.year ?? 2000, month: comps.month ?? 1)
    }

    func adding(months: Int) -> YearMonth {
        YearMonth(year: year, month: month + months)
    }

    func months(from other: YearMonth) -> Int {
        (year * 12 + month) - (other.year * 12 + other.month)
    }

    func firstDay(calendar: Calendar = AppCalendar.calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? .distantPast
    }

    var name: String { TurkishMonths.names[month - 1] }
    var longLabel: String { "\(name) \(year)" }
    var shortLabel: String { "\(TurkishMonths.shortNames[month - 1]) \(year)" }

    static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        lhs.months(from: rhs) < 0
    }
}
```

- [ ] **Step 7: Testleri çalıştır**

Run: `xcodegen generate && xcodebuild test -project OdemeTakip.xcodeproj -scheme OdemeTakip -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`
Expected: PASS (8 test).

- [ ] **Step 8: Commit**

```bash
git add .gitignore project.yml OdemeTakip.xcodeproj OdemeTakip OdemeTakipTests
git commit -m "chore: scaffold Xcode project with YearMonth and currency types

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: MoneyFormatter + AmountParser

**Files:**
- Create: `OdemeTakip/Logic/MoneyFormatter.swift`, `OdemeTakip/Logic/AmountParser.swift`
- Test: `OdemeTakipTests/MoneyFormatterTests.swift`, `OdemeTakipTests/AmountParserTests.swift`

**Interfaces:**
- Consumes: `Currency` (Task 1)
- Produces:
  - `enum MoneyFormatter { static func string(_ amount: Decimal, _ currency: Currency) -> String; static func joined(_ amounts: [Currency: Decimal]) -> String }`
  - `enum AmountParser { static func parse(_ text: String) -> Decimal?; static func editingText(_ amount: Decimal) -> String }`

- [ ] **Step 1: Failing testler yaz**

`OdemeTakipTests/MoneyFormatterTests.swift`:

```swift
import Foundation
import Testing
@testable import OdemeTakip

struct MoneyFormatterTests {
    @Test func wholeAmountsHaveNoFraction() {
        #expect(MoneyFormatter.string(15_000, .TRY) == "₺15.000")
        #expect(MoneyFormatter.string(2_400, .USD) == "$2.400")
        #expect(MoneyFormatter.string(0, .TRY) == "₺0")
    }

    @Test func fractionalAmountsShowTwoDigits() {
        #expect(MoneyFormatter.string(Decimal(string: "1234.5") ?? 0, .EUR) == "€1.234,50")
    }

    @Test func joinedOrdersByCurrencyAndSkipsZero() {
        let text = MoneyFormatter.joined([.USD: 2_400, .TRY: 50_000, .EUR: 0])
        #expect(text == "₺50.000 + $2.400")
    }

    @Test func joinedEmptyIsZeroLira() {
        #expect(MoneyFormatter.joined([:]) == "₺0")
    }
}
```

`OdemeTakipTests/AmountParserTests.swift`:

```swift
import Foundation
import Testing
@testable import OdemeTakip

struct AmountParserTests {
    @Test(arguments: [
        ("15000", "15000"),
        ("15.000", "15000"),
        ("1.500.000", "1500000"),
        ("1.500,50", "1500.5"),
        ("1500,5", "1500.5"),
        ("12.5", "12.5"),
        (" ₺7.500 ", "7500"),
        ("0", "0"),
    ])
    func parsesTurkishInput(input: String, expected: String) {
        #expect(AmountParser.parse(input) == Decimal(string: expected))
    }

    @Test(arguments: ["", "abc", "-5", "1,999", "1,2,3", "12.34.5", "1.50.000"])
    func rejectsInvalidInput(input: String) {
        #expect(AmountParser.parse(input) == nil)
    }

    @Test func editingTextRoundTrips() {
        let value = Decimal(string: "1500.5") ?? 0
        #expect(AmountParser.editingText(value) == "1500,5")
        #expect(AmountParser.editingText(7_500) == "7500")
        #expect(AmountParser.parse(AmountParser.editingText(value)) == value)
    }
}
```

- [ ] **Step 2: Çalıştır, FAIL gör**

Run: test komutu (Global Constraints).
Expected: FAIL — `cannot find 'MoneyFormatter' in scope`.

- [ ] **Step 3: `OdemeTakip/Logic/MoneyFormatter.swift`**

```swift
import Foundation

enum MoneyFormatter {
    static func string(_ amount: Decimal, _ currency: Currency) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        let hasFraction = amount != amount.roundedToWhole
        formatter.minimumFractionDigits = hasFraction ? 2 : 0
        formatter.maximumFractionDigits = 2
        let number = formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
        return currency.symbol + number
    }

    /// Para birimlerini sırayla "₺50.000 + $2.400" şeklinde birleştirir; sıfırları atlar.
    static func joined(_ amounts: [Currency: Decimal]) -> String {
        let parts = amounts
            .filter { $0.value != 0 }
            .sorted { $0.key < $1.key }
            .map { string($0.value, $0.key) }
        return parts.isEmpty ? string(0, .TRY) : parts.joined(separator: " + ")
    }
}

extension Decimal {
    var roundedToWhole: Decimal {
        var source = self
        var result = Decimal()
        NSDecimalRound(&result, &source, 0, .plain)
        return result
    }
}
```

- [ ] **Step 4: `OdemeTakip/Logic/AmountParser.swift`**

```swift
import Foundation

enum AmountParser {
    /// Türkçe klavye girdisini çevirir: "1.500,50", "15.000", "15000", "1500,5".
    /// Negatif, 2'den fazla küsurat veya bozuk gruplama → nil.
    static func parse(_ text: String) -> Decimal? {
        var value = text
        for token in ["₺", "$", "€", " ", "\u{00A0}"] {
            value = value.replacingOccurrences(of: token, with: "")
        }
        guard !value.isEmpty else { return nil }

        if value.contains(",") {
            if value.contains(".") {
                guard value.range(of: #"^\d{1,3}(\.\d{3})+,\d+$"#, options: .regularExpression) != nil else { return nil }
            }
            value = value.replacingOccurrences(of: ".", with: "")
            value = value.replacingOccurrences(of: ",", with: ".")
        } else if value.range(of: #"^\d{1,3}(\.\d{3})+$"#, options: .regularExpression) != nil {
            value = value.replacingOccurrences(of: ".", with: "")
        }

        guard value.range(of: #"^\d+(\.\d{1,2})?$"#, options: .regularExpression) != nil else { return nil }
        return Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Düzenleme formu için gruplamasız metin: 1500.5 → "1500,5".
    static func editingText(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.decimalSeparator = ","
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}
```

- [ ] **Step 5: Testleri çalıştır**

Run: test komutu.
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add OdemeTakip/Logic OdemeTakipTests OdemeTakip.xcodeproj
git commit -m "feat: add Turkish money formatting and amount parsing

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

(Yeni dosya eklenince her task'ta `xcodegen generate` çalıştırılır; test komutundan önce.)

---

### Task 3: PaymentSnapshot + PaymentCalculator

**Files:**
- Create: `OdemeTakip/Logic/PaymentSnapshot.swift`, `OdemeTakip/Logic/PaymentCalculator.swift`
- Test: `OdemeTakipTests/PaymentCalculatorTests.swift`

**Interfaces:**
- Consumes: `YearMonth`, `Currency`, `PaymentKind` (Task 1)
- Produces:
  - `struct PaymentSnapshot: Identifiable, Equatable, Sendable` alanları: `id: UUID, kind, currency, installmentCount: Int, monthlyAmount: Decimal, firstMonth: YearMonth, paidInstallments: Set<Int>, totalDebt: Decimal, cashPaid: Decimal, cashPaymentCount: Int`; fabrikalar `static func credit(_ currency: Currency = .TRY, count: Int, monthly: Decimal, first: YearMonth, paid: Set<Int> = []) -> PaymentSnapshot`, `static func cash(_ currency: Currency = .TRY, debt: Decimal, paid: Decimal = 0, paymentCount: Int = 0) -> PaymentSnapshot`
  - `struct DueSummary: Equatable, Sendable { var amount: Decimal; var count: Int }`
  - `struct Totals: Equatable, Sendable { var credit: [Currency: Decimal]; var cash: [Currency: Decimal]; var overall: [Currency: Decimal] }`
  - `enum ThisMonthStatus: Equatable { case none, allPaid, due([Currency: DueSummary]) }`
  - `struct InstallmentRow: Identifiable, Equatable, Sendable { let index: Int; let month: YearMonth; let isPaid: Bool; let isCurrent: Bool; var id: Int }`
  - `struct CreditSchedule: Equatable { let allRows: [InstallmentRow]; let collapsedPaidCount: Int; var visibleRows: [InstallmentRow] }`
  - `enum PaymentCalculator` static: `paidCount(_:) -> Int`, `total(_:) -> Decimal`, `paid(_:) -> Decimal`, `remaining(_:) -> Decimal`, `isCompleted(_:) -> Bool`, `installmentMonth(_:index:) -> YearMonth`, `lastInstallmentMonth(_:) -> YearMonth?`, `installmentIndex(_:in:) -> Int?`, `dueUnpaid(_:in:) -> [Currency: DueSummary]`, `thisMonthStatus(_:in:) -> ThisMonthStatus`, `totals(_:) -> Totals`, `primaryCurrency(_:) -> Currency`, `schedule(_:current:) -> CreditSchedule`

- [ ] **Step 1: Failing test — `OdemeTakipTests/PaymentCalculatorTests.swift`**

```swift
import Foundation
import Testing
@testable import OdemeTakip

struct PaymentCalculatorTests {
    let sep2025 = YearMonth(year: 2025, month: 9)
    let oct2026 = YearMonth(year: 2026, month: 10)

    @Test func creditTotals() {
        let p = PaymentSnapshot.credit(count: 36, monthly: 15_000, first: sep2025, paid: Set(0..<13))
        #expect(PaymentCalculator.total(p) == 540_000)
        #expect(PaymentCalculator.paidCount(p) == 13)
        #expect(PaymentCalculator.paid(p) == 195_000)
        #expect(PaymentCalculator.remaining(p) == 345_000)
        #expect(!PaymentCalculator.isCompleted(p))
    }

    @Test func outOfRangePaidIndexesAreIgnored() {
        let p = PaymentSnapshot.credit(count: 3, monthly: 100, first: sep2025, paid: [0, 5, -1])
        #expect(PaymentCalculator.paidCount(p) == 1)
        #expect(PaymentCalculator.remaining(p) == 200)
    }

    @Test func cashRemainingNeverNegative() {
        #expect(PaymentCalculator.remaining(.cash(debt: 80_000, paid: 30_000, paymentCount: 4)) == 50_000)
        #expect(PaymentCalculator.remaining(.cash(debt: 100, paid: 150, paymentCount: 1)) == 0)
        #expect(PaymentCalculator.isCompleted(.cash(debt: 100, paid: 100, paymentCount: 1)))
    }

    @Test func installmentMonthsCrossYearBoundary() {
        let p = PaymentSnapshot.credit(count: 4, monthly: 10, first: YearMonth(year: 2026, month: 11))
        #expect(PaymentCalculator.installmentMonth(p, index: 2) == YearMonth(year: 2027, month: 1))
        #expect(PaymentCalculator.lastInstallmentMonth(p) == YearMonth(year: 2027, month: 2))
        #expect(PaymentCalculator.installmentIndex(p, in: YearMonth(year: 2027, month: 1)) == 2)
        #expect(PaymentCalculator.installmentIndex(p, in: YearMonth(year: 2026, month: 10)) == nil)
        #expect(PaymentCalculator.installmentIndex(p, in: YearMonth(year: 2027, month: 3)) == nil)
    }

    @Test func dueUnpaidGroupsByCurrencyAndSkipsPaid() {
        let payments: [PaymentSnapshot] = [
            .credit(count: 36, monthly: 15_000, first: sep2025),                       // Ekim 2026 = index 13, ödenmedi
            .credit(count: 16, monthly: 7_500, first: YearMonth(year: 2026, month: 2)), // index 8, ödenmedi
            .credit(.USD, count: 10, monthly: 300, first: oct2026, paid: [0]),          // ödendi
            .credit(.USD, count: 2, monthly: 999, first: YearMonth(year: 2024, month: 1)), // bitti
            .cash(debt: 50_000),
        ]
        let due = PaymentCalculator.dueUnpaid(payments, in: oct2026)
        #expect(due == [.TRY: DueSummary(amount: 22_500, count: 2)])
    }

    @Test func thisMonthStatusStates() {
        #expect(PaymentCalculator.thisMonthStatus([.cash(debt: 10)], in: oct2026) == .none)
        let paid = PaymentSnapshot.credit(count: 2, monthly: 100, first: oct2026, paid: [0])
        #expect(PaymentCalculator.thisMonthStatus([paid], in: oct2026) == .allPaid)
        let unpaid = PaymentSnapshot.credit(count: 2, monthly: 100, first: oct2026)
        #expect(PaymentCalculator.thisMonthStatus([unpaid], in: oct2026) == .due([.TRY: DueSummary(amount: 100, count: 1)]))
    }

    @Test func totalsNeverMixCurrencies() {
        let payments: [PaymentSnapshot] = [
            .credit(count: 10, monthly: 1_000, first: oct2026),
            .credit(.USD, count: 2, monthly: 50, first: oct2026),
            .cash(debt: 5_000, paid: 1_000, paymentCount: 1),
            .cash(.USD, debt: 2_400),
            .cash(.EUR, debt: 100, paid: 100, paymentCount: 1), // tamamlandı → yok
        ]
        let t = PaymentCalculator.totals(payments)
        #expect(t.credit == [.TRY: 10_000, .USD: 100])
        #expect(t.cash == [.TRY: 4_000, .USD: 2_400])
        #expect(t.overall == [.TRY: 14_000, .USD: 2_500])
    }

    @Test func primaryCurrencyRules() {
        #expect(PaymentCalculator.primaryCurrency([]) == .TRY)
        #expect(PaymentCalculator.primaryCurrency([.cash(.USD, debt: 1), .cash(.USD, debt: 1), .cash(debt: 1)]) == .USD)
        #expect(PaymentCalculator.primaryCurrency([.cash(.USD, debt: 1), .cash(debt: 1)]) == .TRY)
        #expect(PaymentCalculator.primaryCurrency([.cash(.EUR, debt: 1), .cash(.USD, debt: 1)]) == .USD)
        #expect(PaymentCalculator.primaryCurrency([.cash(.USD, debt: 1, paid: 1, paymentCount: 1), .cash(.EUR, debt: 5)]) == .EUR)
    }

    @Test func scheduleCollapsesLeadingPaidPastMonths() {
        let p = PaymentSnapshot.credit(count: 36, monthly: 15_000, first: sep2025, paid: Set(0..<13))
        let s = PaymentCalculator.schedule(p, current: oct2026)
        #expect(s.allRows.count == 36)
        #expect(s.collapsedPaidCount == 13)          // Eyl 2025 – Eyl 2026
        #expect(s.visibleRows.first?.month == oct2026)
        #expect(s.visibleRows.first?.isPaid == false)
        #expect(s.allRows[13].isCurrent)
        #expect(!s.allRows[12].isCurrent)
    }

    @Test func overduePastMonthStopsCollapse() {
        let p = PaymentSnapshot.credit(count: 6, monthly: 10, first: YearMonth(year: 2026, month: 5), paid: [0, 2])
        let s = PaymentCalculator.schedule(p, current: oct2026)
        #expect(s.collapsedPaidCount == 1)
        #expect(s.visibleRows.first?.index == 1)
    }
}
```

- [ ] **Step 2: Çalıştır, FAIL gör**

Run: `xcodegen generate` + test komutu.
Expected: FAIL — `cannot find 'PaymentSnapshot' in scope`.

- [ ] **Step 3: `OdemeTakip/Logic/PaymentSnapshot.swift`**

```swift
import Foundation

/// SwiftData modelinin değer kopyası. Tüm hesaplar bunun üzerinde çalışır.
struct PaymentSnapshot: Identifiable, Equatable, Sendable {
    var id = UUID()
    var kind: PaymentKind
    var currency: Currency
    var installmentCount = 0
    var monthlyAmount: Decimal = 0
    var firstMonth = YearMonth(year: 2000, month: 1)
    var paidInstallments: Set<Int> = []
    var totalDebt: Decimal = 0
    var cashPaid: Decimal = 0
    var cashPaymentCount = 0

    static func credit(_ currency: Currency = .TRY, count: Int, monthly: Decimal,
                       first: YearMonth, paid: Set<Int> = []) -> PaymentSnapshot {
        PaymentSnapshot(kind: .credit, currency: currency, installmentCount: count,
                        monthlyAmount: monthly, firstMonth: first, paidInstallments: paid)
    }

    static func cash(_ currency: Currency = .TRY, debt: Decimal, paid: Decimal = 0,
                     paymentCount: Int = 0) -> PaymentSnapshot {
        PaymentSnapshot(kind: .cash, currency: currency, totalDebt: debt,
                        cashPaid: paid, cashPaymentCount: paymentCount)
    }
}
```

- [ ] **Step 4: `OdemeTakip/Logic/PaymentCalculator.swift`**

```swift
import Foundation

struct DueSummary: Equatable, Sendable {
    var amount: Decimal
    var count: Int
}

struct Totals: Equatable, Sendable {
    var credit: [Currency: Decimal]
    var cash: [Currency: Decimal]
    var overall: [Currency: Decimal]
}

enum ThisMonthStatus: Equatable {
    case none
    case allPaid
    case due([Currency: DueSummary])
}

struct InstallmentRow: Identifiable, Equatable, Sendable {
    let index: Int
    let month: YearMonth
    let isPaid: Bool
    let isCurrent: Bool
    var id: Int { index }
}

struct CreditSchedule: Equatable {
    let allRows: [InstallmentRow]
    let collapsedPaidCount: Int
    var visibleRows: [InstallmentRow] { Array(allRows.dropFirst(collapsedPaidCount)) }
}

enum PaymentCalculator {
    static func paidCount(_ p: PaymentSnapshot) -> Int {
        switch p.kind {
        case .credit: p.paidInstallments.filter { $0 >= 0 && $0 < p.installmentCount }.count
        case .cash: p.cashPaymentCount
        }
    }

    static func total(_ p: PaymentSnapshot) -> Decimal {
        switch p.kind {
        case .credit: Decimal(max(p.installmentCount, 0)) * p.monthlyAmount
        case .cash: p.totalDebt
        }
    }

    static func paid(_ p: PaymentSnapshot) -> Decimal {
        switch p.kind {
        case .credit: Decimal(paidCount(p)) * p.monthlyAmount
        case .cash: p.cashPaid
        }
    }

    static func remaining(_ p: PaymentSnapshot) -> Decimal {
        max(Decimal(0), total(p) - paid(p))
    }

    static func isCompleted(_ p: PaymentSnapshot) -> Bool { remaining(p) == 0 }

    static func installmentMonth(_ p: PaymentSnapshot, index: Int) -> YearMonth {
        p.firstMonth.adding(months: index)
    }

    static func lastInstallmentMonth(_ p: PaymentSnapshot) -> YearMonth? {
        p.installmentCount > 0 ? installmentMonth(p, index: p.installmentCount - 1) : nil
    }

    static func installmentIndex(_ p: PaymentSnapshot, in month: YearMonth) -> Int? {
        guard p.kind == .credit else { return nil }
        let index = month.months(from: p.firstMonth)
        return (0..<max(p.installmentCount, 0)).contains(index) ? index : nil
    }

    static func dueUnpaid(_ payments: [PaymentSnapshot], in month: YearMonth) -> [Currency: DueSummary] {
        var result: [Currency: DueSummary] = [:]
        for p in payments {
            guard let index = installmentIndex(p, in: month), !p.paidInstallments.contains(index) else { continue }
            var summary = result[p.currency] ?? DueSummary(amount: 0, count: 0)
            summary.amount += p.monthlyAmount
            summary.count += 1
            result[p.currency] = summary
        }
        return result
    }

    static func thisMonthStatus(_ payments: [PaymentSnapshot], in month: YearMonth) -> ThisMonthStatus {
        let hasInstallment = payments.contains { installmentIndex($0, in: month) != nil }
        guard hasInstallment else { return .none }
        let due = dueUnpaid(payments, in: month)
        return due.isEmpty ? .allPaid : .due(due)
    }

    static func totals(_ payments: [PaymentSnapshot]) -> Totals {
        var totals = Totals(credit: [:], cash: [:], overall: [:])
        for p in payments {
            let left = remaining(p)
            guard left > 0 else { continue }
            switch p.kind {
            case .credit: totals.credit[p.currency, default: 0] += left
            case .cash: totals.cash[p.currency, default: 0] += left
            }
            totals.overall[p.currency, default: 0] += left
        }
        return totals
    }

    /// Kalanı olan kayıtlarda en sık kullanılan para birimi; eşitlikte TL, sonra USD, EUR.
    static func primaryCurrency(_ payments: [PaymentSnapshot]) -> Currency {
        var counts: [Currency: Int] = [:]
        for p in payments where remaining(p) > 0 {
            counts[p.currency, default: 0] += 1
        }
        return Currency.allCases.sorted { a, b in
            let ca = counts[a] ?? 0
            let cb = counts[b] ?? 0
            return ca != cb ? ca > cb : a < b
        }.first ?? .TRY
    }

    static func schedule(_ p: PaymentSnapshot, current: YearMonth) -> CreditSchedule {
        let rows = (0..<max(p.installmentCount, 0)).map { index in
            let month = installmentMonth(p, index: index)
            return InstallmentRow(index: index, month: month,
                                  isPaid: p.paidInstallments.contains(index),
                                  isCurrent: month == current)
        }
        var collapsed = 0
        for row in rows {
            guard row.isPaid, row.month < current else { break }
            collapsed += 1
        }
        return CreditSchedule(allRows: rows, collapsedPaidCount: collapsed)
    }
}
```

- [ ] **Step 5: Testleri çalıştır**

Run: test komutu.
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add OdemeTakip/Logic OdemeTakipTests OdemeTakip.xcodeproj
git commit -m "feat: add payment calculations and credit schedule

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: NotificationContentBuilder

**Files:**
- Create: `OdemeTakip/Logic/NotificationContentBuilder.swift`
- Test: `OdemeTakipTests/NotificationContentBuilderTests.swift`

**Interfaces:**
- Consumes: `PaymentCalculator.dueUnpaid`, `PaymentCalculator.totals`, `MoneyFormatter.joined`, `YearMonth`
- Produces:
  - `struct NotificationContent: Equatable, Sendable { let title: String; let body: String }`
  - `enum NotificationContentBuilder { static let hour = 9; static func content(for month: YearMonth, payments: [PaymentSnapshot]) -> NotificationContent?; static func triggerDate(for month: YearMonth, calendar: Calendar) -> Date; static func triggerMonths(after now: Date, count: Int = 12, calendar: Calendar = AppCalendar.calendar) -> [YearMonth] }`

- [ ] **Step 1: Failing test — `OdemeTakipTests/NotificationContentBuilderTests.swift`**

```swift
import Foundation
import Testing
@testable import OdemeTakip

struct NotificationContentBuilderTests {
    let nov2026 = YearMonth(year: 2026, month: 11)

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        AppCalendar.calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min)) ?? .distantPast
    }

    @Test func creditAndCashOnSeparateLines() {
        let payments: [PaymentSnapshot] = [
            .credit(count: 36, monthly: 15_000, first: YearMonth(year: 2025, month: 9)),
            .credit(count: 16, monthly: 7_500, first: YearMonth(year: 2026, month: 2)),
            .cash(debt: 80_000, paid: 30_000, paymentCount: 4),
            .cash(.USD, debt: 3_000, paid: 600, paymentCount: 1),
        ]
        let content = NotificationContentBuilder.content(for: nov2026, payments: payments)
        #expect(content == NotificationContent(
            title: "Kasım ödemeleri",
            body: "Kredi: ₺22.500 (2 taksit)\nElden kalan: ₺50.000 + $2.400"))
    }

    @Test func creditOnlySkipsPaidInstallments() {
        let payments: [PaymentSnapshot] = [
            .credit(count: 12, monthly: 1_000, first: nov2026),
            .credit(.USD, count: 12, monthly: 300, first: nov2026),
            .credit(count: 12, monthly: 5_000, first: nov2026, paid: [0]),
        ]
        let content = NotificationContentBuilder.content(for: nov2026, payments: payments)
        #expect(content?.body == "Kredi: ₺1.000 + $300 (2 taksit)")
    }

    @Test func cashOnly() {
        let content = NotificationContentBuilder.content(for: nov2026, payments: [.cash(debt: 50_000)])
        #expect(content?.body == "Elden kalan: ₺50.000")
    }

    @Test func nothingDueReturnsNil() {
        let payments: [PaymentSnapshot] = [
            .credit(count: 1, monthly: 100, first: nov2026, paid: [0]),
            .cash(debt: 100, paid: 100, paymentCount: 1),
        ]
        #expect(NotificationContentBuilder.content(for: nov2026, payments: payments) == nil)
        #expect(NotificationContentBuilder.content(for: nov2026, payments: []) == nil)
    }

    @Test func triggerMonthsStartNextMonthMidMonth() {
        let months = NotificationContentBuilder.triggerMonths(after: date(2026, 10, 19, 15))
        #expect(months.count == 12)
        #expect(months.first == YearMonth(year: 2026, month: 11))
        #expect(months.last == YearMonth(year: 2027, month: 10))
    }

    @Test func triggerMonthsIncludeTodayBeforeNine() {
        let months = NotificationContentBuilder.triggerMonths(after: date(2026, 11, 1, 8, 30))
        #expect(months.first == YearMonth(year: 2026, month: 11))
    }

    @Test func triggerMonthsSkipTodayAfterNine() {
        let months = NotificationContentBuilder.triggerMonths(after: date(2026, 11, 1, 9, 30))
        #expect(months.first == YearMonth(year: 2026, month: 12))
    }

    @Test func triggerMonthsCrossYear() {
        let months = NotificationContentBuilder.triggerMonths(after: date(2026, 12, 15, 10), count: 2)
        #expect(months == [YearMonth(year: 2027, month: 1), YearMonth(year: 2027, month: 2)])
    }
}
```

- [ ] **Step 2: Çalıştır, FAIL gör**

Run: `xcodegen generate` + test komutu.
Expected: FAIL — `cannot find 'NotificationContentBuilder' in scope`.

- [ ] **Step 3: `OdemeTakip/Logic/NotificationContentBuilder.swift`**

```swift
import Foundation

struct NotificationContent: Equatable, Sendable {
    let title: String
    let body: String
}

enum NotificationContentBuilder {
    static let hour = 9

    static func content(for month: YearMonth, payments: [PaymentSnapshot]) -> NotificationContent? {
        var lines: [String] = []

        let due = PaymentCalculator.dueUnpaid(payments, in: month)
        if !due.isEmpty {
            let amounts = due.mapValues(\.amount)
            let count = due.values.reduce(0) { $0 + $1.count }
            lines.append("Kredi: \(MoneyFormatter.joined(amounts)) (\(count) taksit)")
        }

        let cash = PaymentCalculator.totals(payments).cash
        if !cash.isEmpty {
            lines.append("Elden kalan: \(MoneyFormatter.joined(cash))")
        }

        guard !lines.isEmpty else { return nil }
        return NotificationContent(title: "\(month.name) ödemeleri", body: lines.joined(separator: "\n"))
    }

    static func triggerDate(for month: YearMonth, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: month.year, month: month.month, day: 1, hour: hour)) ?? .distantPast
    }

    /// `now` sonrasındaki ilk `count` adet "ayın 1'i 09:00" anının ayları.
    static func triggerMonths(after now: Date, count: Int = 12,
                              calendar: Calendar = AppCalendar.calendar) -> [YearMonth] {
        var result: [YearMonth] = []
        var month = YearMonth(date: now, calendar: calendar)
        while result.count < count {
            if triggerDate(for: month, calendar: calendar) > now {
                result.append(month)
            }
            month = month.adding(months: 1)
        }
        return result
    }
}
```

- [ ] **Step 4: Testleri çalıştır**

Run: test komutu.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add OdemeTakip/Logic OdemeTakipTests OdemeTakip.xcodeproj
git commit -m "feat: build monthly notification content

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Form taslakları (PaymentDraft, CashPaymentDraft)

**Files:**
- Create: `OdemeTakip/Logic/PaymentDraft.swift`, `OdemeTakip/Logic/CashPaymentDraft.swift`
- Test: `OdemeTakipTests/PaymentDraftTests.swift`

**Interfaces:**
- Consumes: `AmountParser.parse`, `MoneyFormatter.string`, `PaymentSnapshot.credit`, `YearMonth`, `Currency`, `PaymentKind`
- Produces:
  - `struct PaymentDraft: Equatable` — alanlar: `kind, name, icon, currency, installmentCountText, monthlyAmountText, firstMonth: YearMonth, prepaidCountText, totalDebtText, isEditing: Bool, minimumInstallmentCount: Int, minimumTotalDebt: Decimal`; `init(firstMonth:)`; hesaplananlar: `trimmedName: String`, `installmentCount: Int?`, `monthlyAmount: Decimal?`, `prepaidCount: Int?`, `totalDebt: Decimal?`, `validationMessage: String?`, `isValid: Bool`, `hasInput: Bool`, `preview: PaymentSnapshot?`; statikler: `maxInstallments = 480`, `maxAmount: Decimal`, `icons: [String]`, `defaultIcon(for:) -> String`
  - `struct CashPaymentDraft: Equatable { var amountText: String; var date: Date; let remaining: Decimal; let currency: Currency; var amount: Decimal?; var validationMessage: String? }` + `init(remaining:currency:)`

- [ ] **Step 1: Failing test — `OdemeTakipTests/PaymentDraftTests.swift`**

```swift
import Foundation
import Testing
@testable import OdemeTakip

struct PaymentDraftTests {
    private func creditDraft() -> PaymentDraft {
        var d = PaymentDraft(firstMonth: YearMonth(year: 2026, month: 2))
        d.kind = .credit
        d.name = "  Araç Kredisi "
        d.installmentCountText = "16"
        d.monthlyAmountText = "7.500"
        d.prepaidCountText = "8"
        return d
    }

    @Test func validCreditDraftBuildsPreview() {
        let d = creditDraft()
        #expect(d.isValid)
        #expect(d.trimmedName == "Araç Kredisi")
        let preview = d.preview
        #expect(preview.map(PaymentCalculator.total) == 120_000)
        #expect(preview.map(PaymentCalculator.remaining) == 60_000)
        #expect(preview.flatMap(PaymentCalculator.lastInstallmentMonth) == YearMonth(year: 2027, month: 5))
    }

    @Test func emptyPrepaidMeansZero() {
        var d = creditDraft()
        d.prepaidCountText = ""
        #expect(d.prepaidCount == 0)
        #expect(d.isValid)
    }

    @Test func creditValidationMessages() {
        var d = creditDraft()
        d.name = "   "
        #expect(d.validationMessage == "Ad gerekli")

        d = creditDraft(); d.installmentCountText = "0"
        #expect(d.validationMessage == "Taksit sayısı 1–480 arası olmalı")
        d.installmentCountText = "481"
        #expect(!d.isValid)

        d = creditDraft(); d.monthlyAmountText = "0"
        #expect(d.validationMessage == "Geçerli bir aylık tutar gir")
        d.monthlyAmountText = "abc"
        #expect(!d.isValid)

        d = creditDraft(); d.prepaidCountText = "17"
        #expect(d.validationMessage == "Önceden ödenen taksit 0–16 arası olmalı")
    }

    @Test func editingCannotDropBelowPaidInstallments() {
        var d = creditDraft()
        d.isEditing = true
        d.minimumInstallmentCount = 10
        d.installmentCountText = "9"
        #expect(d.validationMessage == "Taksit sayısı ödenmiş taksitlerden (10) az olamaz")
        d.installmentCountText = "10"
        #expect(d.isValid)
        #expect(d.prepaidCount == 0)
        #expect(d.preview == nil)
    }

    @Test func cashDraftValidation() {
        var d = PaymentDraft(firstMonth: YearMonth(year: 2026, month: 10))
        d.kind = .cash
        d.name = "Ahmet"
        d.totalDebtText = ""
        #expect(d.validationMessage == "Geçerli bir toplam borç gir")
        d.totalDebtText = "80.000"
        #expect(d.isValid)
        #expect(d.totalDebt == 80_000)
    }

    @Test func editingCashCannotDropBelowPaid() {
        var d = PaymentDraft(firstMonth: YearMonth(year: 2026, month: 10))
        d.kind = .cash
        d.name = "Ahmet"
        d.isEditing = true
        d.minimumTotalDebt = 30_000
        d.totalDebtText = "20000"
        #expect(d.validationMessage == "Toplam borç ödenen tutardan (₺30.000) az olamaz")
    }

    @Test func hasInputDetectsTyping() {
        var d = PaymentDraft(firstMonth: YearMonth(year: 2026, month: 10))
        #expect(!d.hasInput)
        d.monthlyAmountText = "5"
        #expect(d.hasInput)
    }

    @Test func cashPaymentCannotExceedRemaining() {
        var d = CashPaymentDraft(remaining: 50_000, currency: .TRY)
        #expect(d.amount == nil)
        #expect(d.validationMessage == nil)
        d.amountText = "60.000"
        #expect(d.amount == nil)
        #expect(d.validationMessage == "Kalan borçtan (₺50.000) fazla olamaz")
        d.amountText = "0"
        #expect(d.validationMessage == "Geçerli bir tutar gir")
        d.amountText = "50.000"
        #expect(d.amount == 50_000)
        #expect(d.validationMessage == nil)
    }
}
```

- [ ] **Step 2: Çalıştır, FAIL gör**

Run: `xcodegen generate` + test komutu.
Expected: FAIL — `cannot find 'PaymentDraft' in scope`.

- [ ] **Step 3: `OdemeTakip/Logic/PaymentDraft.swift`**

```swift
import Foundation

struct PaymentDraft: Equatable {
    static let maxInstallments = 480
    static let maxAmount: Decimal = 1_000_000_000_000
    static let icons = ["🏦", "🏠", "🚗", "💳", "📱", "🎓", "🤝", "💵", "👤", "🛒", "🏥", "✈️"]

    static func defaultIcon(for kind: PaymentKind) -> String {
        kind == .credit ? "🏦" : "🤝"
    }

    var kind: PaymentKind = .credit
    var name = ""
    var icon = PaymentDraft.defaultIcon(for: .credit)
    var currency: Currency = .TRY
    var installmentCountText = ""
    var monthlyAmountText = ""
    var firstMonth: YearMonth
    var prepaidCountText = ""
    var totalDebtText = ""
    var isEditing = false
    /// Düzenlemede: ödenmiş en büyük taksit no + 1.
    var minimumInstallmentCount = 1
    /// Düzenlemede: elden ödenen toplam.
    var minimumTotalDebt: Decimal = 0

    init(firstMonth: YearMonth) {
        self.firstMonth = firstMonth
    }

    var trimmedName: String { Self.trim(name) }

    var installmentCount: Int? {
        guard let value = Int(Self.trim(installmentCountText)),
              (1...Self.maxInstallments).contains(value),
              value >= minimumInstallmentCount else { return nil }
        return value
    }

    var monthlyAmount: Decimal? { Self.positiveAmount(monthlyAmountText) }

    var prepaidCount: Int? {
        if isEditing { return 0 }
        let text = Self.trim(prepaidCountText)
        if text.isEmpty { return 0 }
        guard let value = Int(text), value >= 0, let count = installmentCount, value <= count else { return nil }
        return value
    }

    var totalDebt: Decimal? {
        guard let value = Self.positiveAmount(totalDebtText), value >= minimumTotalDebt else { return nil }
        return value
    }

    var validationMessage: String? {
        if trimmedName.isEmpty { return "Ad gerekli" }
        switch kind {
        case .credit:
            guard let count = Int(Self.trim(installmentCountText)),
                  (1...Self.maxInstallments).contains(count) else {
                return "Taksit sayısı 1–\(Self.maxInstallments) arası olmalı"
            }
            if count < minimumInstallmentCount {
                return "Taksit sayısı ödenmiş taksitlerden (\(minimumInstallmentCount)) az olamaz"
            }
            if monthlyAmount == nil { return "Geçerli bir aylık tutar gir" }
            if prepaidCount == nil { return "Önceden ödenen taksit 0–\(count) arası olmalı" }
        case .cash:
            guard let debt = Self.positiveAmount(totalDebtText) else { return "Geçerli bir toplam borç gir" }
            if debt < minimumTotalDebt {
                return "Toplam borç ödenen tutardan (\(MoneyFormatter.string(minimumTotalDebt, currency))) az olamaz"
            }
        }
        return nil
    }

    var isValid: Bool { validationMessage == nil }

    var hasInput: Bool {
        ![name, installmentCountText, monthlyAmountText, totalDebtText].allSatisfy { Self.trim($0).isEmpty }
    }

    /// Yeni kredi formu için canlı özet.
    var preview: PaymentSnapshot? {
        guard !isEditing, isValid, kind == .credit,
              let count = installmentCount, let monthly = monthlyAmount, let prepaid = prepaidCount else { return nil }
        return .credit(currency, count: count, monthly: monthly, first: firstMonth, paid: Set(0..<prepaid))
    }

    private static func positiveAmount(_ text: String) -> Decimal? {
        guard let value = AmountParser.parse(text), value > 0, value <= maxAmount else { return nil }
        return value
    }

    private static func trim(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

- [ ] **Step 4: `OdemeTakip/Logic/CashPaymentDraft.swift`**

```swift
import Foundation

struct CashPaymentDraft: Equatable {
    var amountText = ""
    var date = Date.now
    let remaining: Decimal
    let currency: Currency

    init(remaining: Decimal, currency: Currency) {
        self.remaining = remaining
        self.currency = currency
    }

    var amount: Decimal? {
        guard let value = AmountParser.parse(amountText), value > 0, value <= remaining else { return nil }
        return value
    }

    /// Boş girişte mesaj yok (Kaydet zaten pasif).
    var validationMessage: String? {
        if amountText.trimmingCharacters(in: .whitespaces).isEmpty { return nil }
        guard let value = AmountParser.parse(amountText), value > 0 else { return "Geçerli bir tutar gir" }
        if value > remaining {
            return "Kalan borçtan (\(MoneyFormatter.string(remaining, currency))) fazla olamaz"
        }
        return nil
    }
}
```

- [ ] **Step 5: Testleri çalıştır**

Run: test komutu.
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add OdemeTakip/Logic OdemeTakipTests OdemeTakip.xcodeproj
git commit -m "feat: add form drafts with validation

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: SwiftData modelleri + kalıcılık

**Files:**
- Create: `OdemeTakip/Models/Payment.swift`, `OdemeTakip/Models/CashPayment.swift`, `OdemeTakip/App/Persistence.swift`
- Test: `OdemeTakipTests/PaymentModelTests.swift`

**Interfaces:**
- Consumes: `PaymentDraft`, `PaymentSnapshot`, `AmountParser.editingText`, `YearMonth`
- Produces:
  - `@Model final class Payment` — kalıcı alanlar: `id: UUID, name, icon, kindRaw, currencyRaw, createdAt, installmentCount, monthlyAmount: Decimal, firstYear: Int, firstMonthNumber: Int, paidInstallmentIndexes: [Int], totalDebt: Decimal, cashPayments: [CashPayment]?`; hesaplanan: `kind`, `currency`, `firstMonth: YearMonth`, `snapshot: PaymentSnapshot`, `sortedCashPayments: [CashPayment]`; metodlar: `static func make(from: PaymentDraft) -> Payment?`, `@discardableResult func apply(_: PaymentDraft) -> Bool`, `func makeDraft() -> PaymentDraft`, `func toggleInstallment(_ index: Int)`, `func addCashPayment(amount: Decimal, date: Date)`, `func removeCashPayment(_ entry: CashPayment)`
  - `@Model final class CashPayment { id: UUID; amount: Decimal; date: Date; payment: Payment? }`
  - `enum Log { static let app: Logger }`
  - `struct PersistenceStore { let container: ModelContainer?; let isTemporary: Bool; static func make() -> PersistenceStore }`
  - `extension ModelContext { func saveQuietly() }`

- [ ] **Step 1: Failing test — `OdemeTakipTests/PaymentModelTests.swift`**

```swift
import Foundation
import SwiftData
import Testing
@testable import OdemeTakip

@MainActor
struct PaymentModelTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        container = try ModelContainer(for: Payment.self, CashPayment.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = container.mainContext
    }

    private func creditDraft() -> PaymentDraft {
        var d = PaymentDraft(firstMonth: YearMonth(year: 2026, month: 2))
        d.kind = .credit
        d.name = "Araç"
        d.icon = "🚗"
        d.installmentCountText = "16"
        d.monthlyAmountText = "7.500"
        d.prepaidCountText = "8"
        return d
    }

    private func cashPayment(debt: String = "80000") throws -> Payment {
        var d = PaymentDraft(firstMonth: YearMonth(year: 2026, month: 10))
        d.kind = .cash
        d.name = "Ahmet"
        d.totalDebtText = debt
        let p = try #require(Payment.make(from: d))
        context.insert(p)
        return p
    }

    @Test func creditFromDraftMarksPrepaid() throws {
        let p = try #require(Payment.make(from: creditDraft()))
        context.insert(p)
        try context.save()
        #expect(p.kind == .credit)
        #expect(p.firstMonth == YearMonth(year: 2026, month: 2))
        #expect(p.paidInstallmentIndexes == Array(0..<8))
        #expect(PaymentCalculator.remaining(p.snapshot) == 60_000)
    }

    @Test func invalidDraftMakesNothing() {
        var d = creditDraft()
        d.name = ""
        #expect(Payment.make(from: d) == nil)
    }

    @Test func toggleInstallment() throws {
        let p = try #require(Payment.make(from: creditDraft()))
        context.insert(p)
        p.toggleInstallment(8)
        #expect(p.paidInstallmentIndexes.contains(8))
        p.toggleInstallment(8)
        #expect(!p.paidInstallmentIndexes.contains(8))
        p.toggleInstallment(99)
        #expect(!p.paidInstallmentIndexes.contains(99))
    }

    @Test func editDraftCarriesMinimums() throws {
        let p = try #require(Payment.make(from: creditDraft()))
        context.insert(p)
        let d = p.makeDraft()
        #expect(d.isEditing)
        #expect(d.minimumInstallmentCount == 8)
        #expect(d.monthlyAmountText == "7500")
        #expect(d.installmentCountText == "16")
        #expect(d.isValid)
    }

    @Test func applyEditKeepsPaidInstallments() throws {
        let p = try #require(Payment.make(from: creditDraft()))
        context.insert(p)
        var d = p.makeDraft()
        d.installmentCountText = "10"
        d.monthlyAmountText = "8000"
        #expect(p.apply(d))
        #expect(p.installmentCount == 10)
        #expect(p.monthlyAmount == 8_000)
        #expect(p.paidInstallmentIndexes == Array(0..<8))
    }

    @Test func cashPaymentsAddAndRemove() throws {
        let p = try cashPayment()
        p.addCashPayment(amount: 10_000, date: .now)
        p.addCashPayment(amount: 20_000, date: .now.addingTimeInterval(-86_400))
        try context.save()
        #expect(p.snapshot.cashPaid == 30_000)
        #expect(p.snapshot.cashPaymentCount == 2)
        #expect(p.sortedCashPayments.first?.amount == 10_000)

        let first = try #require(p.sortedCashPayments.first)
        p.removeCashPayment(first)
        try context.save()
        #expect(p.snapshot.cashPaid == 20_000)
        #expect(p.makeDraft().minimumTotalDebt == 20_000)
    }

    @Test func deletingPaymentCascades() throws {
        let p = try cashPayment()
        p.addCashPayment(amount: 5_000, date: .now)
        try context.save()
        context.delete(p)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<CashPayment>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Payment>()) == 0)
    }
}
```

- [ ] **Step 2: Çalıştır, FAIL gör**

Run: `xcodegen generate` + test komutu.
Expected: FAIL — `cannot find 'Payment' in scope`.

- [ ] **Step 3: `OdemeTakip/Models/CashPayment.swift`**

```swift
import Foundation
import SwiftData

@Model
final class CashPayment {
    var id = UUID()
    var amount: Decimal = 0
    var date = Date.now
    var payment: Payment?

    init(amount: Decimal, date: Date) {
        self.amount = amount
        self.date = date
    }
}
```

- [ ] **Step 4: `OdemeTakip/Models/Payment.swift`**

```swift
import Foundation
import SwiftData

@Model
final class Payment {
    var id = UUID()
    var name = ""
    var icon = "🏦"
    var kindRaw = PaymentKind.credit.rawValue
    var currencyRaw = Currency.TRY.rawValue
    var createdAt = Date.now
    // Kredi
    var installmentCount = 0
    var monthlyAmount: Decimal = 0
    var firstYear = 2000
    var firstMonthNumber = 1
    var paidInstallmentIndexes: [Int] = []
    // Elden
    var totalDebt: Decimal = 0
    @Relationship(deleteRule: .cascade, inverse: \CashPayment.payment)
    var cashPayments: [CashPayment]? = []

    init(kind: PaymentKind) {
        self.kindRaw = kind.rawValue
    }

    var kind: PaymentKind {
        get { PaymentKind(rawValue: kindRaw) ?? .credit }
        set { kindRaw = newValue.rawValue }
    }

    var currency: Currency {
        get { Currency(rawValue: currencyRaw) ?? .TRY }
        set { currencyRaw = newValue.rawValue }
    }

    var firstMonth: YearMonth {
        get { YearMonth(year: firstYear, month: firstMonthNumber) }
        set {
            firstYear = newValue.year
            firstMonthNumber = newValue.month
        }
    }

    private var liveCashPayments: [CashPayment] {
        (cashPayments ?? []).filter { !$0.isDeleted }
    }

    var sortedCashPayments: [CashPayment] {
        liveCashPayments.sorted { $0.date > $1.date }
    }

    var snapshot: PaymentSnapshot {
        let entries = liveCashPayments
        return PaymentSnapshot(
            id: id, kind: kind, currency: currency,
            installmentCount: installmentCount, monthlyAmount: monthlyAmount,
            firstMonth: firstMonth, paidInstallments: Set(paidInstallmentIndexes),
            totalDebt: totalDebt,
            cashPaid: entries.reduce(Decimal(0)) { $0 + $1.amount },
            cashPaymentCount: entries.count)
    }

    static func make(from draft: PaymentDraft) -> Payment? {
        guard draft.isValid else { return nil }
        let payment = Payment(kind: draft.kind)
        return payment.apply(draft) ? payment : nil
    }

    @discardableResult
    func apply(_ draft: PaymentDraft) -> Bool {
        guard draft.isValid, draft.kind == kind else { return false }
        switch kind {
        case .credit:
            guard let count = draft.installmentCount, let monthly = draft.monthlyAmount,
                  let prepaid = draft.prepaidCount else { return false }
            installmentCount = count
            monthlyAmount = monthly
            firstMonth = draft.firstMonth
            if draft.isEditing {
                paidInstallmentIndexes = paidInstallmentIndexes.filter { $0 < count }
            } else {
                paidInstallmentIndexes = Array(0..<prepaid)
            }
        case .cash:
            guard let debt = draft.totalDebt else { return false }
            totalDebt = debt
        }
        name = draft.trimmedName
        icon = draft.icon
        currency = draft.currency
        return true
    }

    func makeDraft() -> PaymentDraft {
        var draft = PaymentDraft(firstMonth: firstMonth)
        draft.kind = kind
        draft.name = name
        draft.icon = icon
        draft.currency = currency
        draft.isEditing = true
        switch kind {
        case .credit:
            draft.installmentCountText = String(installmentCount)
            draft.monthlyAmountText = AmountParser.editingText(monthlyAmount)
            draft.minimumInstallmentCount = max(1, (paidInstallmentIndexes.max() ?? -1) + 1)
        case .cash:
            draft.totalDebtText = AmountParser.editingText(totalDebt)
            draft.minimumTotalDebt = snapshot.cashPaid
        }
        return draft
    }

    func toggleInstallment(_ index: Int) {
        guard kind == .credit, (0..<installmentCount).contains(index) else { return }
        if let position = paidInstallmentIndexes.firstIndex(of: index) {
            paidInstallmentIndexes.remove(at: position)
        } else {
            paidInstallmentIndexes.append(index)
            paidInstallmentIndexes.sort()
        }
    }

    func addCashPayment(amount: Decimal, date: Date) {
        let entry = CashPayment(amount: amount, date: date)
        modelContext?.insert(entry)
        entry.payment = self
    }

    func removeCashPayment(_ entry: CashPayment) {
        modelContext?.delete(entry)
    }
}
```

- [ ] **Step 5: `OdemeTakip/App/Persistence.swift`**

```swift
import Foundation
import OSLog
import SwiftData

enum Log {
    static let app = Logger(subsystem: "com.alpiysl.odemetakip", category: "app")
}

struct PersistenceStore {
    let container: ModelContainer?
    /// Kalıcı depo açılamadı, bellek içi çalışılıyor.
    let isTemporary: Bool

    static func make() -> PersistenceStore {
        let schema = Schema([Payment.self, CashPayment.self])
        do {
            return PersistenceStore(container: try ModelContainer(for: schema), isTemporary: false)
        } catch {
            Log.app.error("Persistent store failed: \(error.localizedDescription, privacy: .public)")
        }
        do {
            let memory = ModelConfiguration(isStoredInMemoryOnly: true)
            return PersistenceStore(container: try ModelContainer(for: schema, configurations: memory), isTemporary: true)
        } catch {
            Log.app.error("In-memory store failed: \(error.localizedDescription, privacy: .public)")
            return PersistenceStore(container: nil, isTemporary: true)
        }
    }
}

extension ModelContext {
    func saveQuietly() {
        do {
            try save()
        } catch {
            Log.app.error("Save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
```

- [ ] **Step 6: Testleri çalıştır**

Run: `xcodegen generate` + test komutu.
Expected: PASS (tüm testler).

- [ ] **Step 7: Commit**

```bash
git add OdemeTakip OdemeTakipTests OdemeTakip.xcodeproj
git commit -m "feat: add SwiftData models and persistence setup

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Tema, uygulama girişi, bildirim planlayıcı, ana sayfa

**Files:**
- Create: `OdemeTakip/Theme/Theme.swift`, `OdemeTakip/Services/NotificationScheduler.swift`, `OdemeTakip/App/RootView.swift`, `OdemeTakip/App/SampleData.swift`, `OdemeTakip/Views/Components/InfoBanner.swift`, `OdemeTakip/Views/Home/HomeView.swift`, `OdemeTakip/Views/Home/SummaryCardView.swift`, `OdemeTakip/Views/Home/FilterBar.swift`, `OdemeTakip/Views/Home/PaymentRowView.swift`
- Modify: `OdemeTakip/App/OdemeTakipApp.swift` (tamamen değişir)
- Geçici yer tutucu (Task 8–10'da gerçek hali yazılır): `OdemeTakip/Views/Form/PaymentFormView.swift`, `OdemeTakip/Views/CreditDetail/CreditDetailView.swift`, `OdemeTakip/Views/CashDetail/CashDetailView.swift`
- Test: derleme + simülatör ekran görüntüsü (UI)

**Interfaces:**
- Consumes: Task 1–6'daki her şey.
- Produces:
  - `enum Theme` renkleri: `background, surface, divider, footer, ring, credit, cash, paid, accent, gradientStart, secondaryText, tertiaryText`, `static var gradient: LinearGradient`, `static func kindColor(_: PaymentKind) -> Color`; `extension Color { init(hex: UInt32) }`
  - `@MainActor enum NotificationScheduler { static func requestAuthorization() async -> Bool; static func reschedule(payments: [PaymentSnapshot], now: Date = .now) async; static func scheduleTest(payments: [PaymentSnapshot]) async (DEBUG) }`
  - `final class NotificationDelegate` (ön planda banner)
  - `PaymentFormView(mode: PaymentFormView.Mode, onDeleteRequested: (() -> Void)? = nil)` — `enum Mode { case create; case edit(Payment) }`
  - `CreditDetailView(payment: Payment)`, `CashDetailView(payment: Payment)`
  - `InfoBanner(text: String, onClose: (() -> Void)?)`

- [ ] **Step 1: `OdemeTakip/Theme/Theme.swift`**

```swift
import SwiftUI

enum Theme {
    static let background = Color(hex: 0x0B0B0F)
    static let surface = Color(hex: 0x1C1C22)
    static let divider = Color(hex: 0x1F1F26)
    static let footer = Color(hex: 0x15151B)
    static let ring = Color(hex: 0x3A3A44)
    static let credit = Color(hex: 0x64D2FF)
    static let cash = Color(hex: 0xFFD60A)
    static let paid = Color(hex: 0x30D158)
    static let accent = Color(hex: 0xBF5AF2)
    static let gradientStart = Color(hex: 0x5E5CE6)
    static let secondaryText = Color.white.opacity(0.5)
    static let tertiaryText = Color.white.opacity(0.3)

    static var gradient: LinearGradient {
        LinearGradient(colors: [gradientStart, accent], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func kindColor(_ kind: PaymentKind) -> Color {
        kind == .credit ? credit : cash
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }
}
```

- [ ] **Step 2: `OdemeTakip/Services/NotificationScheduler.swift`**

```swift
import Foundation
import UserNotifications

@MainActor
enum NotificationScheduler {
    /// İzin hiç sorulmadıysa sorar. Bildirim gösterilebiliyorsa true.
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                Log.app.error("Notification auth failed: \(error.localizedDescription, privacy: .public)")
                return false
            }
        case .denied:
            return false
        default:
            return true
        }
    }

    /// Bekleyen tüm aylık bildirimleri silip önümüzdeki 12 ay için yeniden kurar.
    static func reschedule(payments: [PaymentSnapshot], now: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        for month in NotificationContentBuilder.triggerMonths(after: now) {
            guard let content = NotificationContentBuilder.content(for: month, payments: payments) else { continue }
            var components = DateComponents()
            components.year = month.year
            components.month = month.month
            components.day = 1
            components.hour = NotificationContentBuilder.hour
            components.minute = 0
            let request = UNNotificationRequest(
                identifier: "monthly-\(month.year)-\(month.month)",
                content: makeContent(content),
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            do {
                try await center.add(request)
            } catch {
                Log.app.error("Schedule failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    #if DEBUG
    /// 5 sn sonra bu ayın bildirimini gösterir (sadece Debug build).
    static func scheduleTest(payments: [PaymentSnapshot]) async {
        let month = YearMonth(date: .now)
        let content = NotificationContentBuilder.content(for: month, payments: payments)
            ?? NotificationContent(title: "\(month.name) ödemeleri", body: "Bu ay ödeme yok")
        let request = UNNotificationRequest(
            identifier: "debug-test",
            content: makeContent(content),
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false))
        try? await UNUserNotificationCenter.current().add(request)
    }
    #endif

    private static func makeContent(_ content: NotificationContent) -> UNMutableNotificationContent {
        let result = UNMutableNotificationContent()
        result.title = content.title
        result.body = content.body
        result.sound = .default
        return result
    }
}

/// Uygulama açıkken de bildirimi banner olarak gösterir.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
```

- [ ] **Step 3: `OdemeTakip/App/OdemeTakipApp.swift` (değiştir)**

```swift
import SwiftUI
import UserNotifications

@main
struct OdemeTakipApp: App {
    private let store = PersistenceStore.make()

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container = store.container {
                    RootView(isTemporaryStore: store.isTemporary)
                        .modelContainer(container)
                } else {
                    ZStack {
                        Theme.background.ignoresSafeArea()
                        InfoBanner(text: "Veri deposu açılamadı. Uygulamayı kapatıp yeniden aç.", onClose: nil)
                            .padding()
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
```

- [ ] **Step 4: `OdemeTakip/App/RootView.swift`**

```swift
import SwiftData
import SwiftUI

struct RootView: View {
    let isTemporaryStore: Bool

    @Query(sort: \Payment.createdAt) private var payments: [Payment]
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @State private var notificationsAllowed = true

    private var snapshots: [PaymentSnapshot] { payments.map(\.snapshot) }

    var body: some View {
        NavigationStack {
            HomeView(payments: payments,
                     notificationsAllowed: notificationsAllowed,
                     isTemporaryStore: isTemporaryStore)
        }
        .tint(Theme.accent)
        .task {
            #if DEBUG
            SampleData.insertIfRequested(into: context)
            #endif
            notificationsAllowed = await NotificationScheduler.requestAuthorization()
            await NotificationScheduler.reschedule(payments: snapshots)
        }
        .task(id: snapshots) {
            await NotificationScheduler.reschedule(payments: snapshots)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                notificationsAllowed = await NotificationScheduler.requestAuthorization()
                await NotificationScheduler.reschedule(payments: snapshots)
            }
        }
    }
}
```

- [ ] **Step 5: `OdemeTakip/App/SampleData.swift`**

```swift
#if DEBUG
import Foundation
import SwiftData

/// `-seedSampleData` argümanıyla açılırsa ve veri yoksa örnek kayıtlar ekler.
enum SampleData {
    @MainActor
    static func insertIfRequested(into context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-seedSampleData"),
              (try? context.fetchCount(FetchDescriptor<Payment>())) == 0 else { return }

        let now = YearMonth(date: .now)

        var home = PaymentDraft(firstMonth: now.adding(months: -13))
        home.kind = .credit; home.name = "Konut Kredisi"; home.icon = "🏠"
        home.installmentCountText = "36"; home.monthlyAmountText = "15000"; home.prepaidCountText = "13"

        var car = PaymentDraft(firstMonth: now.adding(months: -8))
        car.kind = .credit; car.name = "Araç Kredisi"; car.icon = "🚗"
        car.installmentCountText = "16"; car.monthlyAmountText = "7500"; car.prepaidCountText = "8"

        var friend = PaymentDraft(firstMonth: now)
        friend.kind = .cash; friend.name = "Ahmet'e borç"; friend.icon = "🤝"; friend.totalDebtText = "80000"

        var dollar = PaymentDraft(firstMonth: now)
        dollar.kind = .cash; dollar.name = "Dolar borcu"; dollar.icon = "💵"
        dollar.currency = .USD; dollar.totalDebtText = "3000"

        for draft in [home, car, friend, dollar] {
            guard let payment = Payment.make(from: draft) else { continue }
            context.insert(payment)
            if draft.name == "Ahmet'e borç" {
                payment.addCashPayment(amount: 10_000, date: .now)
                payment.addCashPayment(amount: 20_000, date: .now.addingTimeInterval(-40 * 86_400))
            }
            if draft.name == "Dolar borcu" {
                payment.addCashPayment(amount: 600, date: .now)
            }
        }
        context.saveQuietly()
    }
}
#endif
```

- [ ] **Step 6: `OdemeTakip/Views/Components/InfoBanner.swift`**

```swift
import SwiftUI

struct InfoBanner: View {
    let text: String
    let onClose: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill").foregroundStyle(Theme.accent)
            Text(text).font(.footnote).foregroundStyle(.white.opacity(0.85))
            Spacer(minLength: 0)
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(Theme.secondaryText)
                }
                .accessibilityLabel("Kapat")
            }
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
```

- [ ] **Step 7: `OdemeTakip/Views/Home/FilterBar.swift`**

```swift
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
```

- [ ] **Step 8: `OdemeTakip/Views/Home/SummaryCardView.swift`**

```swift
import SwiftUI

struct SummaryCardView: View {
    let snapshots: [PaymentSnapshot]
    let currentMonth: YearMonth

    var body: some View {
        let totals = PaymentCalculator.totals(snapshots)
        let primary = PaymentCalculator.primaryCurrency(snapshots)
        let others = totals.overall.filter { $0.key != primary }

        VStack(alignment: .leading, spacing: 2) {
            Text("Toplam kalan").font(.caption).opacity(0.85)
            Text(MoneyFormatter.string(totals.overall[primary] ?? 0, primary))
                .font(.system(size: 36, weight: .heavy))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if !others.isEmpty {
                Text("+ " + MoneyFormatter.joined(others)).font(.footnote).opacity(0.85)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) { legends(totals) }
                VStack(alignment: .leading, spacing: 4) { legends(totals) }
            }
            .font(.caption)
            .padding(.top, 8)
            chip
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private func legends(_ totals: Totals) -> some View {
        legend(color: Theme.credit, title: "Kredi", value: MoneyFormatter.joined(totals.credit))
        legend(color: Theme.cash, title: "Elden", value: MoneyFormatter.joined(totals.cash))
    }

    private func legend(color: Color, title: String, value: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title)
            Text(value).fontWeight(.bold)
        }
    }

    @ViewBuilder
    private var chip: some View {
        switch PaymentCalculator.thisMonthStatus(snapshots, in: currentMonth) {
        case .none:
            EmptyView()
        case .allPaid:
            chipText("Bu ayın taksitleri ödendi ✓")
        case .due(let due):
            chipText("Bu ay: \(MoneyFormatter.joined(due.mapValues(\.amount))) kredi taksiti")
        }
    }

    private func chipText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.top, 10)
    }
}
```

- [ ] **Step 9: `OdemeTakip/Views/Home/PaymentRowView.swift`**

```swift
import SwiftUI

struct PaymentRowView: View {
    let payment: Payment

    var body: some View {
        let snapshot = payment.snapshot
        HStack(spacing: 12) {
            Text(payment.icon)
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(Theme.kindColor(snapshot.kind).opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(payment.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(Self.subtitle(snapshot)).font(.caption).foregroundStyle(Theme.secondaryText).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(MoneyFormatter.string(PaymentCalculator.remaining(snapshot), snapshot.currency))
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
            Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(Theme.tertiaryText)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Theme.divider.frame(height: 1) }
    }

    static func subtitle(_ s: PaymentSnapshot) -> String {
        switch s.kind {
        case .credit:
            "\(PaymentCalculator.paidCount(s))/\(s.installmentCount) taksit · \(MoneyFormatter.string(s.monthlyAmount, s.currency))/ay"
        case .cash:
            "Elden · \(MoneyFormatter.string(s.cashPaid, s.currency)) ödendi"
        }
    }
}
```

- [ ] **Step 10: `OdemeTakip/Views/Home/HomeView.swift`**

```swift
import SwiftUI

struct HomeView: View {
    let payments: [Payment]
    let notificationsAllowed: Bool
    let isTemporaryStore: Bool

    @State private var filter: HomeFilter = .all
    @State private var showingAdd = false
    @AppStorage("hideNotificationBanner") private var hideNotificationBanner = false

    var body: some View {
        let snapshots = payments.map(\.snapshot)
        let filtered = payments.filter { filter.includes($0.kind) }
        let active = filtered.filter { !PaymentCalculator.isCompleted($0.snapshot) }
        let completed = filtered.filter { PaymentCalculator.isCompleted($0.snapshot) }

        ZStack(alignment: .bottomTrailing) {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if isTemporaryStore {
                        InfoBanner(text: "Veri deposu açılamadı. Girilen veriler uygulama kapanınca silinir.", onClose: nil)
                    }
                    if !notificationsAllowed && !hideNotificationBanner {
                        InfoBanner(text: "Bildirimler kapalı — Ayarlar'dan açabilirsin") {
                            hideNotificationBanner = true
                        }
                    }
                    summaryCard(snapshots)
                    if payments.isEmpty {
                        emptyState
                    } else {
                        FilterBar(selection: $filter)
                        LazyVStack(spacing: 0) {
                            ForEach(active) { row($0) }
                        }
                        if !completed.isEmpty {
                            Text("Tamamlananlar")
                                .font(.caption.weight(.semibold))
                                .textCase(.uppercase)
                                .foregroundStyle(Theme.secondaryText)
                                .padding(.top, 8)
                            LazyVStack(spacing: 0) {
                                ForEach(completed) { row($0).opacity(0.5) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 96)
            }
            addButton
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingAdd) {
            PaymentFormView(mode: .create)
        }
    }

    @ViewBuilder
    private func summaryCard(_ snapshots: [PaymentSnapshot]) -> some View {
        let card = SummaryCardView(snapshots: snapshots, currentMonth: YearMonth(date: .now))
        #if DEBUG
        card.onLongPressGesture {
            Task { await NotificationScheduler.scheduleTest(payments: snapshots) }
        }
        #else
        card
        #endif
    }

    private func row(_ payment: Payment) -> some View {
        NavigationLink {
            switch payment.kind {
            case .credit: CreditDetailView(payment: payment)
            case .cash: CashDetailView(payment: payment)
            }
        } label: {
            PaymentRowView(payment: payment)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Henüz ödeme yok").font(.headline)
            Text("+ ile ilk kaydını ekle").font(.subheadline).foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var addButton: some View {
        Button {
            showingAdd = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Theme.gradient, in: Circle())
                .shadow(color: Theme.accent.opacity(0.45), radius: 12, y: 6)
        }
        .accessibilityLabel("Yeni ödeme")
        .padding(.trailing, 20)
        .padding(.bottom, 24)
    }
}
```

- [ ] **Step 11: Geçici yer tutucular (sonraki task'larda değiştirilir)**

`OdemeTakip/Views/Form/PaymentFormView.swift`:

```swift
import SwiftUI

struct PaymentFormView: View {
    enum Mode {
        case create
        case edit(Payment)
    }

    let mode: Mode
    var onDeleteRequested: (() -> Void)? = nil

    var body: some View { Text("Form") }
}
```

`OdemeTakip/Views/CreditDetail/CreditDetailView.swift`:

```swift
import SwiftUI

struct CreditDetailView: View {
    let payment: Payment
    var body: some View { Text(payment.name) }
}
```

`OdemeTakip/Views/CashDetail/CashDetailView.swift`:

```swift
import SwiftUI

struct CashDetailView: View {
    let payment: Payment
    var body: some View { Text(payment.name) }
}
```

- [ ] **Step 12: Derle + testleri çalıştır**

Run: `xcodegen generate` + test komutu.
Expected: PASS, derleme uyarısız ya da sadece önemsiz uyarılar.

- [ ] **Step 13: Simülatörde ana sayfayı gör**

```bash
xcodebuild -project OdemeTakip.xcodeproj -scheme OdemeTakip -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build -quiet
xcrun simctl boot "iPhone 17" 2>/dev/null; open -a Simulator
xcrun simctl uninstall "iPhone 17" com.alpiysl.odemetakip 2>/dev/null
xcrun simctl install "iPhone 17" build/Build/Products/Debug-iphonesimulator/OdemeTakip.app
xcrun simctl privacy "iPhone 17" grant notifications com.alpiysl.odemetakip 2>/dev/null
xcrun simctl launch "iPhone 17" com.alpiysl.odemetakip -seedSampleData
sleep 3; xcrun simctl io "iPhone 17" screenshot "$SCRATCH/home.png"
```

(`$SCRATCH` = oturumun scratchpad klasörü.) Ekran görüntüsünü oku; beklenen: mor gradyan kart, "Toplam kalan", Kredi/Elden satırı, "Bu ay" çipi, sekmeler, 4 satır, sağ altta + butonu. Mockup `all-screens-v3.html` ekran 1 ile karşılaştır.

- [ ] **Step 14: Commit**

```bash
git add OdemeTakip OdemeTakip.xcodeproj
git commit -m "feat: add home screen, theme and notification scheduling

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Ekleme / düzenleme formu

**Files:**
- Modify: `OdemeTakip/Views/Form/PaymentFormView.swift` (tamamen değiştir)
- Create: `OdemeTakip/Views/Form/MonthPicker.swift`
- Test: derleme + simülatörde elle

**Interfaces:**
- Consumes: `PaymentDraft`, `Payment.make(from:)`, `Payment.apply(_:)`, `Payment.makeDraft()`, `ModelContext.saveQuietly()`, `Theme`
- Produces: `PaymentFormView(mode:onDeleteRequested:)` — silme onaylanınca formu kapatır ve `onDeleteRequested` çağırır; silmeyi çağıran ekran yapar. `MonthPicker(title: String, selection: Binding<YearMonth>)`

- [ ] **Step 1: `OdemeTakip/Views/Form/MonthPicker.swift`**

```swift
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
```

- [ ] **Step 2: `OdemeTakip/Views/Form/PaymentFormView.swift`**

```swift
import SwiftData
import SwiftUI

struct PaymentFormView: View {
    enum Mode {
        case create
        case edit(Payment)
    }

    let mode: Mode
    var onDeleteRequested: (() -> Void)? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var draft: PaymentDraft
    @State private var confirmingDelete = false

    init(mode: Mode, onDeleteRequested: (() -> Void)? = nil) {
        self.mode = mode
        self.onDeleteRequested = onDeleteRequested
        switch mode {
        case .create: _draft = State(initialValue: PaymentDraft(firstMonth: YearMonth(date: .now)))
        case .edit(let payment): _draft = State(initialValue: payment.makeDraft())
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if !draft.isEditing {
                    Section {
                        Picker("Tür", selection: $draft.kind) {
                            ForEach(PaymentKind.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                    }
                }

                Section {
                    TextField("Ad", text: $draft.name)
                        .textInputAutocapitalization(.words)
                    Picker("İkon", selection: $draft.icon) {
                        ForEach(PaymentDraft.icons, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Para birimi", selection: $draft.currency) {
                        ForEach(Currency.allCases) { Text($0.displayName).tag($0) }
                    }
                }
                .listRowBackground(Theme.surface)

                if draft.kind == .credit {
                    Section {
                        numberField("Taksit sayısı", text: $draft.installmentCountText, decimal: false)
                        numberField("Aylık tutar", text: $draft.monthlyAmountText, decimal: true)
                        MonthPicker(title: "İlk taksit ayı", selection: $draft.firstMonth)
                        if !draft.isEditing {
                            numberField("Önceden ödenen taksit", text: $draft.prepaidCountText, decimal: false)
                        }
                    }
                    .listRowBackground(Theme.surface)
                } else {
                    Section {
                        numberField("Toplam borç", text: $draft.totalDebtText, decimal: true)
                    }
                    .listRowBackground(Theme.surface)
                }

                if let preview = draft.preview {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Toplam \(MoneyFormatter.string(PaymentCalculator.total(preview), preview.currency)) · Kalan \(MoneyFormatter.string(PaymentCalculator.remaining(preview), preview.currency))")
                                .font(.subheadline.weight(.semibold))
                            if let last = PaymentCalculator.lastInstallmentMonth(preview) {
                                Text("Son taksit: \(last.longLabel)").font(.caption).foregroundStyle(Theme.secondaryText)
                            }
                        }
                    }
                    .listRowBackground(Theme.credit.opacity(0.1))
                } else if draft.hasInput, let message = draft.validationMessage {
                    Section {
                        Text(message).font(.footnote).foregroundStyle(Theme.cash)
                    }
                    .listRowBackground(Color.clear)
                }

                if draft.isEditing {
                    Section {
                        Button("Kaydı sil", role: .destructive) { confirmingDelete = true }
                    }
                    .listRowBackground(Theme.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(draft.isEditing ? "Düzenle" : "Yeni ödeme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .fontWeight(.bold)
                        .disabled(!draft.isValid)
                }
            }
            .onChange(of: draft.kind) { _, newKind in
                if PaymentKind.allCases.map(PaymentDraft.defaultIcon(for:)).contains(draft.icon) {
                    draft.icon = PaymentDraft.defaultIcon(for: newKind)
                }
            }
            .confirmationDialog("Bu kayıt silinsin mi?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Sil", role: .destructive) {
                    onDeleteRequested?()
                    dismiss()
                }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("Tüm ödeme geçmişi de silinir.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private func numberField(_ title: String, text: Binding<String>, decimal: Bool) -> some View {
        LabeledContent(title) {
            TextField("0", text: text)
                .keyboardType(decimal ? .decimalPad : .numberPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
    }

    private func save() {
        switch mode {
        case .create:
            guard let payment = Payment.make(from: draft) else { return }
            context.insert(payment)
        case .edit(let payment):
            guard payment.apply(draft) else { return }
        }
        context.saveQuietly()
        dismiss()
    }
}
```

- [ ] **Step 3: Derle + test**

Run: `xcodegen generate` + test komutu.
Expected: PASS.

- [ ] **Step 4: Simülatörde elle kontrol**

Task 7 Step 13 komutlarıyla (seed olmadan: `xcrun simctl launch "iPhone 17" com.alpiysl.odemetakip`) aç. Kontrol listesi:
- + → form açılır, Kredi seçili, Kaydet pasif.
- Ad "Test", taksit 12, tutar "1.500,50", önceden 2 → özet "Toplam ₺18.006 · Kalan ₺15.005" ve son taksit ayı görünür, Kaydet aktif.
- Taksit 0 yaz → turuncu mesaj, Kaydet pasif.
- Elden'e geç → ikon 🤝 olur, sadece Toplam borç alanı.
- Kaydet → ana sayfada kayıt ve toplamlar güncellenir.
Ekran görüntüsü al (`$SCRATCH/form.png`), mockup ekran 4 ile karşılaştır.

- [ ] **Step 5: Commit**

```bash
git add OdemeTakip OdemeTakip.xcodeproj
git commit -m "feat: add payment create/edit form

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Kredi detay ekranı

**Files:**
- Modify: `OdemeTakip/Views/CreditDetail/CreditDetailView.swift` (tamamen değiştir)
- Create: `OdemeTakip/Views/CreditDetail/InstallmentRowView.swift`, `OdemeTakip/Views/Components/FooterTotalsView.swift`, `OdemeTakip/Views/Components/PaymentDeletion.swift`
- Test: derleme + simülatörde elle

**Interfaces:**
- Consumes: `PaymentCalculator.schedule`, `Payment.toggleInstallment`, `PaymentFormView(mode:onDeleteRequested:)`, `ModelContext.saveQuietly()`
- Produces:
  - `FooterTotalsView(lines: [FooterTotalsView.Line], resultTitle: String, resultValue: String)` — `struct Line { let title: String; let value: String; var color: Color? = nil }`
  - `enum PaymentDeletion { @MainActor static func deleteAfterPop(_ payment: Payment, in context: ModelContext) }`

- [ ] **Step 1: `OdemeTakip/Views/Components/FooterTotalsView.swift`**

```swift
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
```

- [ ] **Step 2: `OdemeTakip/Views/Components/PaymentDeletion.swift`**

```swift
import SwiftData
import SwiftUI

enum PaymentDeletion {
    /// Detay ekranı geri kapandıktan sonra siler; silinmiş modele erişen görünüm kalmasın.
    @MainActor
    static func deleteAfterPop(_ payment: Payment, in context: ModelContext) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            context.delete(payment)
            context.saveQuietly()
        }
    }
}
```

- [ ] **Step 3: `OdemeTakip/Views/CreditDetail/InstallmentRowView.swift`**

```swift
import SwiftUI

struct InstallmentRowView: View {
    let row: InstallmentRow
    let amount: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if row.isPaid {
                    Circle().fill(Theme.paid)
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(Theme.background)
                } else {
                    Circle().strokeBorder(Theme.ring, lineWidth: 2)
                }
            }
            .frame(width: 24, height: 24)

            HStack(spacing: 4) {
                Text(row.month.longLabel).fontWeight(row.isCurrent ? .bold : .regular)
                Text("· \(row.index + 1). taksit\(row.isCurrent ? " · bu ay" : "")")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            .lineLimit(1)

            Spacer(minLength: 8)

            Text(amount)
                .monospacedDigit()
                .foregroundStyle(row.isPaid ? Theme.paid : (row.isCurrent ? Color.white : Theme.secondaryText))
        }
        .font(.subheadline)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(row.isPaid ? "Ödendi" : "Ödenmedi")
    }
}
```

- [ ] **Step 4: `OdemeTakip/Views/CreditDetail/CreditDetailView.swift`**

```swift
import SwiftData
import SwiftUI

struct CreditDetailView: View {
    let payment: Payment

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showAll = false
    @State private var editing = false
    @State private var deleteRequested = false

    var body: some View {
        if payment.isDeleted || payment.modelContext == nil {
            Theme.background.ignoresSafeArea()
        } else {
            content
        }
    }

    private var content: some View {
        let snapshot = payment.snapshot
        let current = YearMonth(date: .now)
        let schedule = PaymentCalculator.schedule(snapshot, current: current)
        let rows = showAll ? schedule.allRows : schedule.visibleRows
        let amount = MoneyFormatter.string(snapshot.monthlyAmount, snapshot.currency)

        return ScrollViewReader { proxy in
            List {
                Text("\(snapshot.installmentCount) taksit · \(amount)/ay · \(snapshot.firstMonth.shortLabel) başlangıç")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .listRowBackground(Color.clear)

                if schedule.collapsedPaidCount > 0 && !showAll {
                    Button("Önceki \(schedule.collapsedPaidCount) taksit ödendi ✓ (göster)") {
                        showAll = true
                    }
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                ForEach(rows) { row in
                    Button {
                        payment.toggleInstallment(row.index)
                        context.saveQuietly()
                    } label: {
                        InstallmentRowView(row: row, amount: amount)
                    }
                    .buttonStyle(.plain)
                    .id(row.index)
                    .listRowBackground(row.isCurrent ? Theme.accent.opacity(0.08) : Color.clear)
                    .listRowSeparatorTint(Theme.divider)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .onAppear {
                if let index = PaymentCalculator.installmentIndex(snapshot, in: current) {
                    proxy.scrollTo(index, anchor: .center)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FooterTotalsView(
                lines: [
                    .init(title: "Toplam", value: MoneyFormatter.string(PaymentCalculator.total(snapshot), snapshot.currency)),
                    .init(title: "Ödenen (\(PaymentCalculator.paidCount(snapshot)))",
                          value: "− " + MoneyFormatter.string(PaymentCalculator.paid(snapshot), snapshot.currency),
                          color: Theme.paid),
                ],
                resultTitle: "Kalan (\(snapshot.installmentCount - PaymentCalculator.paidCount(snapshot)))",
                resultValue: MoneyFormatter.string(PaymentCalculator.remaining(snapshot), snapshot.currency))
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("\(payment.icon) \(payment.name)")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            Button("Düzenle") { editing = true }
        }
        .sensoryFeedback(.selection, trigger: payment.paidInstallmentIndexes)
        .sheet(isPresented: $editing, onDismiss: handleSheetDismiss) {
            PaymentFormView(mode: .edit(payment), onDeleteRequested: { deleteRequested = true })
        }
    }

    private func handleSheetDismiss() {
        guard deleteRequested else { return }
        dismiss()
        PaymentDeletion.deleteAfterPop(payment, in: context)
    }
}
```

- [ ] **Step 5: Derle + test**

Run: `xcodegen generate` + test komutu.
Expected: PASS.

- [ ] **Step 6: Simülatörde elle kontrol** (`-seedSampleData` ile, temiz kurulum)

- Konut Kredisi'ne gir → bu ay vurgulu ve ortada, "Önceki 13 taksit ödendi ✓ (göster)" satırı, altta Toplam ₺540.000 / Ödenen (13) / Kalan (23) ₺345.000.
- Bu ayın dairesine dokun → yeşil ✓, Kalan ₺330.000 olur; geri dön → ana sayfa kartı ve "Bu ay" çipi güncellenir.
- "göster" → eski aylar açılır.
- Düzenle → taksit sayısını 5 yap → Kaydet pasif, mesaj "Taksit sayısı ödenmiş taksitlerden (14) az olamaz".
- Düzenle → Kaydı sil → Sil → ana sayfaya döner, kayıt yok, uygulama çökmez.
Ekran görüntüsü `$SCRATCH/credit.png`, mockup ekran 2 ile karşılaştır.

- [ ] **Step 7: Commit**

```bash
git add OdemeTakip OdemeTakip.xcodeproj
git commit -m "feat: add credit detail with installment tracking

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Elden detay + ödeme ekleme

**Files:**
- Modify: `OdemeTakip/Views/CashDetail/CashDetailView.swift` (tamamen değiştir)
- Create: `OdemeTakip/Views/CashDetail/AddCashPaymentView.swift`
- Test: derleme + simülatörde elle

**Interfaces:**
- Consumes: `CashPaymentDraft`, `Payment.addCashPayment`, `Payment.removeCashPayment`, `Payment.sortedCashPayments`, `FooterTotalsView`, `PaymentDeletion`, `PaymentFormView`, `TurkishMonths.dayMonth`
- Produces: `AddCashPaymentView(payment: Payment)`

- [ ] **Step 1: `OdemeTakip/Views/CashDetail/AddCashPaymentView.swift`**

```swift
import SwiftData
import SwiftUI

struct AddCashPaymentView: View {
    let payment: Payment

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CashPaymentDraft
    @FocusState private var amountFocused: Bool

    init(payment: Payment) {
        self.payment = payment
        _draft = State(initialValue: CashPaymentDraft(
            remaining: PaymentCalculator.remaining(payment.snapshot),
            currency: payment.currency))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Tutar") {
                        TextField("0", text: $draft.amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .focused($amountFocused)
                    }
                    DatePicker("Tarih", selection: $draft.date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "tr_TR"))
                } footer: {
                    if let message = draft.validationMessage {
                        Text(message).foregroundStyle(Theme.cash)
                    } else {
                        Text("Kalan: \(MoneyFormatter.string(draft.remaining, draft.currency))")
                    }
                }
                .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Ödeme ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .fontWeight(.bold)
                        .disabled(draft.amount == nil)
                }
            }
            .onAppear { amountFocused = true }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium])
    }

    private func save() {
        guard let amount = draft.amount else { return }
        payment.addCashPayment(amount: amount, date: draft.date)
        context.saveQuietly()
        dismiss()
    }
}
```

- [ ] **Step 2: `OdemeTakip/Views/CashDetail/CashDetailView.swift`**

```swift
import SwiftData
import SwiftUI

struct CashDetailView: View {
    let payment: Payment

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var addingPayment = false
    @State private var editing = false
    @State private var deleteRequested = false

    var body: some View {
        if payment.isDeleted || payment.modelContext == nil {
            Theme.background.ignoresSafeArea()
        } else {
            content
        }
    }

    private var content: some View {
        let snapshot = payment.snapshot
        let entries = payment.sortedCashPayments
        let completed = PaymentCalculator.isCompleted(snapshot)

        return List {
            Section {
                Text("Elden · Toplam borç \(MoneyFormatter.string(snapshot.totalDebt, snapshot.currency))")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .listRowBackground(Color.clear)

                if completed {
                    Text("Borç tamamlandı ✓")
                        .font(.headline)
                        .foregroundStyle(Theme.paid)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                } else {
                    Button {
                        addingPayment = true
                    } label: {
                        Text("+ Ödeme ekle")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }

            Section {
                if entries.isEmpty {
                    Text("Henüz ödeme yok")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .listRowBackground(Color.clear)
                }
                ForEach(entries) { entry in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Theme.paid)
                            Image(systemName: "checkmark").font(.caption.weight(.heavy)).foregroundStyle(Theme.background)
                        }
                        .frame(width: 24, height: 24)
                        Text(YearMonth(date: entry.date).longLabel)
                        Text("· \(TurkishMonths.dayMonth(entry.date))")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                        Spacer()
                        Text(MoneyFormatter.string(entry.amount, snapshot.currency))
                            .monospacedDigit()
                            .foregroundStyle(Theme.paid)
                    }
                    .font(.subheadline)
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Theme.divider)
                }
                .onDelete { offsets in
                    for index in offsets { payment.removeCashPayment(entries[index]) }
                    context.saveQuietly()
                }
            } header: {
                Text("Ödeme geçmişi").font(.caption).foregroundStyle(Theme.secondaryText)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FooterTotalsView(
                lines: [
                    .init(title: "Toplam borç", value: MoneyFormatter.string(snapshot.totalDebt, snapshot.currency)),
                    .init(title: "Ödenen (\(snapshot.cashPaymentCount))",
                          value: "− " + MoneyFormatter.string(snapshot.cashPaid, snapshot.currency),
                          color: Theme.paid),
                ],
                resultTitle: "Kalan",
                resultValue: MoneyFormatter.string(PaymentCalculator.remaining(snapshot), snapshot.currency))
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("\(payment.icon) \(payment.name)")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            Button("Düzenle") { editing = true }
        }
        .sheet(isPresented: $addingPayment) {
            AddCashPaymentView(payment: payment)
        }
        .sheet(isPresented: $editing, onDismiss: handleSheetDismiss) {
            PaymentFormView(mode: .edit(payment), onDeleteRequested: { deleteRequested = true })
        }
    }

    private func handleSheetDismiss() {
        guard deleteRequested else { return }
        dismiss()
        PaymentDeletion.deleteAfterPop(payment, in: context)
    }
}
```

- [ ] **Step 3: Derle + test**

Run: `xcodegen generate` + test komutu.
Expected: PASS.

- [ ] **Step 4: Simülatörde elle kontrol** (`-seedSampleData`, temiz kurulum)

- Ahmet'e borç → altta Toplam borç ₺80.000 / Ödenen (2) − ₺30.000 / Kalan ₺50.000.
- + Ödeme ekle → "60.000" yaz → "Kalan borçtan (₺50.000) fazla olamaz", Kaydet pasif. "5.000" → Kaydet → listede en üstte, Kalan ₺45.000.
- Satırı sola kaydır → Sil → Kalan geri ₺50.000.
- Düzenle → toplam borç "1000" → mesaj "Toplam borç ödenen tutardan (₺30.000) az olamaz".
- Kalanı tam öde → "Borç tamamlandı ✓", ana sayfada "Tamamlananlar" altında soluk.
- Düzenle → Kaydı sil → ana sayfaya döner, çökme yok.
Ekran görüntüsü `$SCRATCH/cash.png`, mockup ekran 3 ile karşılaştır.

- [ ] **Step 5: Commit**

```bash
git add OdemeTakip OdemeTakip.xcodeproj
git commit -m "feat: add cash detail and payment entry

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: App icon, açılış rengi, bildirim doğrulaması, kurulum dokümanı

**Files:**
- Create: `scripts/make-icon.swift`, `OdemeTakip/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`, `OdemeTakip/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (betik üretir), `OdemeTakip/Resources/Assets.xcassets/LaunchBackground.colorset/Contents.json`, `docs/KURULUM.md`
- Modify: `project.yml` (`DEVELOPMENT_TEAM`, kullanıcı takım ID'si verince)

**Interfaces:**
- Consumes: logo B tasarımı (`.superpowers/brainstorm/*/content/logo.html`, `#ib`)
- Produces: derlenebilir, imzalanabilir son uygulama.

- [ ] **Step 1: `scripts/make-icon.swift`**

```swift
// Kullanım: swift scripts/make-icon.swift <çıktı.png>
// Logo B: koyu zemin, üstte mor gradyan tuşta beyaz "+", altta gri tuşta sarı "−".
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func color(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

guard CommandLine.arguments.count == 2 else {
    print("usage: swift make-icon.swift <output.png>"); exit(1)
}

let pixels = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

// SVG koordinatları (180x180, y aşağı) → 1024px
let scale = CGFloat(pixels) / 180
ctx.translateBy(x: 0, y: CGFloat(pixels))
ctx.scaleBy(x: scale, y: -scale)

ctx.setFillColor(color(0x0B0B0F))
ctx.fill(CGRect(x: 0, y: 0, width: 180, height: 180))

// Üst tuş (gradyan)
let topKey = CGRect(x: 22, y: 22, width: 136, height: 64)
ctx.saveGState()
ctx.addPath(rounded(topKey, 20))
ctx.clip()
let gradient = CGGradient(colorsSpace: space, colors: [color(0x6E6CF0), color(0xC76AF5)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: topKey.minX, y: topKey.minY),
                       end: CGPoint(x: topKey.maxX, y: topKey.maxY), options: [])
ctx.restoreGState()

// Alt tuş
ctx.setFillColor(color(0x26262E))
ctx.addPath(rounded(CGRect(x: 22, y: 94, width: 136, height: 64), 20))
ctx.fillPath()

// +
ctx.setFillColor(color(0xFFFFFF))
ctx.addPath(rounded(CGRect(x: 70, y: 48, width: 40, height: 12), 6))
ctx.addPath(rounded(CGRect(x: 84, y: 34, width: 12, height: 40), 6))
ctx.fillPath()

// −
ctx.setFillColor(color(0xFFD60A))
ctx.addPath(rounded(CGRect(x: 70, y: 120, width: 40, height: 12), 6))
ctx.fillPath()

let image = ctx.makeImage()!
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { print("write failed"); exit(1) }
print("wrote \(url.path)")
```

- [ ] **Step 2: Asset dosyaları**

`OdemeTakip/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`:

```json
{
  "images" : [
    { "filename" : "AppIcon.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

`OdemeTakip/Resources/Assets.xcassets/LaunchBackground.colorset/Contents.json`:

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "red" : "0.043", "green" : "0.043", "blue" : "0.059" }
      },
      "idiom" : "universal"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

Run: `swift scripts/make-icon.swift OdemeTakip/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
Expected: `wrote …/AppIcon.png`. PNG'yi Read ile aç, logo B'ye benzediğini doğrula.

- [ ] **Step 3: Derle + test + simülatörde ikon ve bildirim**

Run: `xcodegen generate` + test komutu → PASS.
Sonra Task 7 Step 13 komutlarıyla `-seedSampleData` ile aç:
- Simülatörde ana ekrana dön (`xcrun simctl ui "iPhone 17" appearance dark` gerekmez) → ikon logo B, ad "Ödeme Takip". Ekran görüntüsü `$SCRATCH/icon.png`.
- Uygulamada özet karta uzun bas → 5 sn içinde banner: "Ekim ödemeleri" / "Kredi: ₺22.500 (2 taksit)" / "Elden kalan: ₺50.000 + $2.400" (ay ve rakamlar o güne göre). Ekran görüntüsü `$SCRATCH/notif.png`, mockup ekran 5 ile karşılaştır.
- Açılışta beyaz flaş yok (koyu açılış ekranı).

- [ ] **Step 4: `docs/KURULUM.md`**

````markdown
# iPhone'a Kurulum (ücretsiz Apple ID)

## Bir kerelik hazırlık
1. Xcode → Settings → Accounts → **+** → Apple ID ile giriş yap.
2. iPhone'u kabloyla Mac'e bağla, telefonda "Bu bilgisayara güven" de.
3. iPhone: Ayarlar → Gizlilik ve Güvenlik → **Geliştirici Modu** → Aç → telefon yeniden başlar → onayla.
4. Terminal: `cd ~/Repos/odemeTakipApp && open OdemeTakip.xcodeproj`
5. Xcode'da OdemeTakip target → Signing & Capabilities → Team: **(Personal Team)** seç.

## Kurulum
1. Xcode üst çubuğunda cihaz olarak iPhone'unu seç.
2. **Run** (⌘R). Run şeması Release build alır (hızlı, debug özelliği yok).
3. İlk açılışta "Güvenilmeyen Geliştirici" çıkarsa: iPhone → Ayarlar → Genel → VPN ve Aygıt Yönetimi → geliştirici uygulaması → **Güven**.
4. Uygulama açılınca bildirim iznine **İzin Ver** de.

## Her 7 günde bir (önemli)
Ücretsiz hesapla imza 7 gün geçerli. Süre dolunca uygulama açılmaz.
- 7 gün dolmadan: telefonu bağla → Xcode → Run. Veriler korunur.
- Süre dolduysa da aynı işlem; veriler yine korunur.
- **Uygulamayı telefondan silme** — silersen tüm veriler gider.
- Bildirimler uygulama her açıldığında 12 ay ileriye planlanır; kilitli uygulama açılamazsa yeni planlama yapılmaz, bu yüzden haftalık yenilemeyi aksatma.
````

- [ ] **Step 5: Takım ID'sini `project.yml`'a yaz**

Kullanıcı Xcode'da Personal Team seçtikten sonra:
Run: `grep -m1 DEVELOPMENT_TEAM OdemeTakip.xcodeproj/project.pbxproj`
Çıkan ID'yi `project.yml` → `settings.base.DEVELOPMENT_TEAM` değerine yaz, `xcodegen generate` çalıştır (sonraki üretimlerde takım silinmesin).

- [ ] **Step 6: Son tam test**

Run: test komutu → PASS.
Run: `grep -rnE 'fatalError|try!|as!' OdemeTakip/` → çıktı boş olmalı.
Run: `grep -rnE '[a-zA-Z0-9_)\]]!(\.|\)|,|$| )' OdemeTakip/ --include=*.swift` → çıktıyı oku; `!=`, `!` (mantıksal değil) dışında force unwrap kalmamalı.

- [ ] **Step 7: Commit**

```bash
git add scripts OdemeTakip project.yml OdemeTakip.xcodeproj docs/KURULUM.md
git commit -m "feat: add app icon, launch color and install guide

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
