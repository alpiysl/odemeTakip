import XCTest

/// Gerçek dokunma akışları; örnek veriyle (-resetData -seedSampleData) sıfırdan başlar.
@MainActor
final class OdemeTakipUITests: XCTestCase {
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUp() async throws {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetData", "-seedSampleData", "-fakeRates"] + extra
        app.launch()
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 4) { allow.tap() }
        XCTAssertTrue(app.descendants(matching: .any)["splash"].waitForNonExistence(timeout: 5))
        return app
    }

    private func text(_ app: XCUIApplication, _ value: String) -> XCUIElement {
        app.staticTexts[value]
    }

    func testCreditInstallmentToggleUpdatesTotals() {
        let app = launch()
        XCTAssertTrue(text(app, "Konut Kredisi").waitForExistence(timeout: 5))
        text(app, "Konut Kredisi").tap()

        XCTAssertTrue(text(app, "₺345.000").waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'bu ay'")).firstMatch.tap()
        XCTAssertTrue(text(app, "₺330.000").waitForExistence(timeout: 3))

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(text(app, "Bu ay: ₺7.500 kredi taksiti").waitForExistence(timeout: 3))
    }

    func testCashPaymentValidationAddAndDeleteRecord() {
        let app = launch()
        XCTAssertTrue(text(app, "Ahmet'e borç").waitForExistence(timeout: 5))
        text(app, "Ahmet'e borç").tap()

        app.buttons["+ Ödeme ekle"].tap()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("60000")
        XCTAssertTrue(text(app, "Kalan borçtan (₺50.000) fazla olamaz").waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Kaydet"].isEnabled)

        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5) + "5000")
        XCTAssertTrue(app.buttons["Kaydet"].isEnabled)
        app.buttons["Kaydet"].tap()
        XCTAssertTrue(text(app, "₺45.000").waitForExistence(timeout: 3))

        app.buttons["Düzenle"].tap()
        app.buttons["Kaydı sil"].tap()
        app.buttons["Sil"].firstMatch.tap()

        XCTAssertTrue(text(app, "Konut Kredisi").waitForExistence(timeout: 5))
        XCTAssertFalse(text(app, "Ahmet'e borç").waitForExistence(timeout: 2))
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testCreateCreditFromForm() {
        let app = launch()
        XCTAssertTrue(app.buttons["Yeni ödeme"].waitForExistence(timeout: 5))
        app.buttons["Yeni ödeme"].tap()

        XCTAssertFalse(app.buttons["Kaydet"].isEnabled)
        app.textFields["Ad"].tap()
        app.textFields["Ad"].typeText("Telefon")
        let numbers = app.textFields.matching(NSPredicate(format: "placeholderValue == '0'"))
        numbers.element(boundBy: 0).tap()
        numbers.element(boundBy: 0).typeText("12")
        app.buttons["Bitti"].tap()
        numbers.element(boundBy: 1).tap()
        numbers.element(boundBy: 1).typeText("1000")
        XCTAssertTrue(text(app, "Toplam ₺12.000 · Kalan ₺12.000").waitForExistence(timeout: 3))
        XCTAssertTrue(app.keyboards.element.exists)
        app.buttons["Bitti"].tap()
        XCTAssertTrue(app.keyboards.element.waitForNonExistence(timeout: 3))

        app.textFields["Ad"].tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 3))
        app.segmentedControls.buttons["Elden"].tap()
        XCTAssertTrue(app.keyboards.element.waitForNonExistence(timeout: 3))
        app.segmentedControls.buttons["Kredi"].tap()
        app.buttons["Kaydet"].tap()

        XCTAssertTrue(text(app, "Telefon").waitForExistence(timeout: 3))
    }

    func testMonthlyNotificationBannerShows() {
        let app = launch(["-testNotification"])
        XCTAssertTrue(text(app, "Toplam kalan").waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        sleep(8)
        // Bildirim Merkezi'ni aç: teslim edilen bildirim listede kalır.
        let top = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.01))
        top.press(forDuration: 0.1, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.7)))
        let banner = springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[cd] 'odemeleri'")).firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 15))
        let label = banner.label
        XCTAssertTrue(label.contains("Kredi:"), label)
        XCTAssertTrue(label.contains("Elden kalan:"), label)
    }

    func testSplashThenLiraTotalsWithRates() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetData", "-seedSampleData", "-fakeRates"]
        app.launch()
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 4) { allow.tap() }
        XCTAssertTrue(app.descendants(matching: .any)["splash"].waitForNonExistence(timeout: 5))

        // ₺455.000 + $2.400 × 40 = ₺551.000
        XCTAssertTrue(text(app, "₺551.000").waitForExistence(timeout: 5))
        let rateBar = app.descendants(matching: .any)["rateBar"]
        XCTAssertTrue(rateBar.label.contains("1$ = ₺40 · 1€ = ₺50 · TCMB 19 Eki"), rateBar.label)
        XCTAssertTrue(text(app, "≈ ₺96.000").exists)
        XCTAssertFalse(text(app, "+ $2.400").exists)
    }
}
