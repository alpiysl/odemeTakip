import XCTest

/// Gerçek dokunma akışları; örnek veriyle (-resetData -seedSampleData) sıfırdan başlar.
@MainActor
final class OdemeTakipUITests: XCTestCase {
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUp() async throws {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String] = [], mode: String = "debt") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetData", "-seedSampleData", "-fakeRates", "-startMode", mode] + extra
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
        app.launchArguments = ["-resetData", "-seedSampleData", "-fakeRates", "-startMode", "debt"]
        app.launch()
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 4) { allow.tap() }
        XCTAssertTrue(app.descendants(matching: .any)["splash"].waitForNonExistence(timeout: 5))

        // ₺455.000 + $2.400 × 40 = ₺551.000
        XCTAssertTrue(text(app, "₺551.000").waitForExistence(timeout: 5))
        let rateBar = app.descendants(matching: .any)["rateBar"]
        XCTAssertTrue(rateBar.label.contains("$ ₺40 · € ₺50 · Gr ₺6.000"), rateBar.label)
        XCTAssertTrue(rateBar.label.hasSuffix("TCMB 19 Eki"), rateBar.label)
        XCTAssertTrue(text(app, "≈ ₺96.000").exists)
        XCTAssertFalse(text(app, "+ $2.400").exists)
    }

    // MARK: Varlık Takip

    func testOnboardingChoiceIsRemembered() {
        let app = launch(mode: "none")
        XCTAssertTrue(app.buttons["onboarding-savings"].waitForExistence(timeout: 5))
        app.buttons["onboarding-savings"].tap()
        app.buttons["Devam"].tap()
        XCTAssertTrue(text(app, "Toplam varlık").waitForExistence(timeout: 3))

        app.terminate()
        app.launchArguments = ["-fakeRates"]
        app.launch()
        XCTAssertTrue(text(app, "Toplam varlık").waitForExistence(timeout: 6))
    }

    func testModeToggleShowsToastThenFades() {
        let app = launch()
        XCTAssertTrue(text(app, "Toplam kalan").waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["netWorth"].firstMatch.exists)
        app.buttons["mode-savings"].tap()
        let toast = app.staticTexts["Ana ekran: Birikim Takip"]
        XCTAssertTrue(toast.waitForExistence(timeout: 2))
        XCTAssertTrue(text(app, "Toplam varlık").exists)
        XCTAssertTrue(toast.waitForNonExistence(timeout: 4))
    }

    func testSavingsTotalsAndNetWorth() {
        let app = launch(mode: "savings")
        // 50 gr × 6.000 + 12 çeyrek × 10.000 + 10.000 $ × 40 + ₺209.319 + alacak ₺120.000
        XCTAssertTrue(text(app, "₺1.149.319").waitForExistence(timeout: 5))
        // Net = 1.149.319 − borç 551.000
        let net = app.descendants(matching: .any)["netWorth"].firstMatch
        XCTAssertTrue(net.label.contains("₺598.319"), net.label)
        let rateBar = app.descendants(matching: .any)["rateBar"]
        XCTAssertTrue(rateBar.label.contains("Gr ₺6.000 · Çyr ₺10.000 · Yrm ₺20.000 · Tam ₺40.000 · Reşat ₺41.000"), rateBar.label)
    }

    func testAssetDepositAndWithdrawLimit() {
        let app = launch(mode: "savings")
        XCTAssertTrue(text(app, "Altın").waitForExistence(timeout: 5))
        text(app, "Altın").tap()
        XCTAssertTrue(text(app, "₺300.000").waitForExistence(timeout: 3))

        app.buttons["+ Ekle"].tap()
        app.textFields.firstMatch.typeText("10")
        app.buttons["Kaydet"].tap()
        XCTAssertTrue(text(app, "₺360.000").waitForExistence(timeout: 3))

        app.buttons["− Çıkar"].tap()
        app.textFields.firstMatch.typeText("100")
        XCTAssertTrue(text(app, "Mevcut miktardan (60 gr) fazla çıkarılamaz").waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Kaydet"].isEnabled)
    }

    func testReceivableCollection() {
        let app = launch(mode: "savings")
        XCTAssertTrue(text(app, "Mehmet").waitForExistence(timeout: 5))
        text(app, "Mehmet").tap()
        app.buttons["+ Tahsilat ekle"].tap()
        let field = app.textFields.firstMatch
        field.typeText("200000")
        XCTAssertTrue(text(app, "Kalan alacaktan (₺120.000) fazla olamaz").waitForExistence(timeout: 3))
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + "20000")
        app.buttons["Kaydet"].tap()
        XCTAssertTrue(text(app, "₺100.000").waitForExistence(timeout: 3))
        XCTAssertTrue(text(app, "Kalan alacak").exists)
    }

    func testAddResatGoldFromMenu() {
        let app = launch(mode: "savings")
        XCTAssertTrue(app.buttons["Yeni kayıt"].waitForExistence(timeout: 5))
        app.buttons["Yeni kayıt"].tap()
        app.buttons["Birikim ekle"].tap()
        app.textFields["Ad"].tap()
        app.textFields["Ad"].typeText("Reşatlar")
        app.buttons["Bitti"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Tür'")).firstMatch.tap()
        app.buttons["Reşat altın"].tap()
        app.textFields["0"].tap()
        app.textFields["0"].typeText("2")
        app.buttons["Kaydet"].tap()
        XCTAssertTrue(text(app, "Reşatlar").waitForExistence(timeout: 3))
        XCTAssertTrue(text(app, "₺82.000").exists)
    }
}
