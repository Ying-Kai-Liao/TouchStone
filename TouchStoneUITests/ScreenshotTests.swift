import XCTest

final class ScreenshotTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = true
        app.launch()
    }

    override func tearDownWithError() throws {
        // No cleanup needed
    }

    func testCaptureAllScreenshots() throws {
        // Wait for app to fully load
        sleep(2)

        // 1. Capture Flow tab (default/first tab)
        takeScreenshot(named: "01-Flow")

        // 2. Navigate to Calendar tab
        let calendarTab = app.tabBars.buttons["Calendar"]
        if calendarTab.waitForExistence(timeout: 5) {
            calendarTab.tap()
            sleep(1)
            takeScreenshot(named: "02-Calendar")
        }

        // 3. Navigate to Plan tab
        let planTab = app.tabBars.buttons["Plan"]
        if planTab.waitForExistence(timeout: 5) {
            planTab.tap()
            sleep(1)
            takeScreenshot(named: "03-Plan")
        }

        // 4. Navigate to Me tab
        let meTab = app.tabBars.buttons["Me"]
        if meTab.waitForExistence(timeout: 5) {
            meTab.tap()
            sleep(1)
            takeScreenshot(named: "04-Me")
        }
    }

    private func takeScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
