import Foundation
import XCTest

final class ScreenshotUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("UITestScreenshots")
        app.launch()
        waitForAppToSettle()
    }

    func testCaptureMainMenus() throws {
        capture("01_dashboard")

        openDashboardSheet(buttonLabel: "Diet Goal", expectedTitle: "Diet Goal", screenshotName: "02_diet_goal")
        openDashboardSheet(buttonLabel: "Manual Entry", expectedTitle: "Manual Entry", screenshotName: "03_manual_entry")
        openDashboardSheet(buttonLabel: "AI Scan", expectedTitle: "AI Entry", screenshotName: "04_ai_entry")

        tapTab("History")
        capture("05_history")

        tapTab("Stats")
        capture("06_stats")

        tapTab("Settings")
        scrollToAboutMe()
        capture("07_about_me")
    }

    private func openDashboardSheet(buttonLabel: String, expectedTitle: String, screenshotName: String) {
        tapTab("Today")

        let button = app.buttons[buttonLabel]
        XCTAssertTrue(button.waitForExistence(timeout: 6), "Missing button: \(buttonLabel)")
        button.tap()

        waitForTitle(expectedTitle)
        capture(screenshotName)
        dismissCurrentSheet()
    }

    private func tapTab(_ label: String) {
        let tabButton = app.tabBars.buttons[label]
        XCTAssertTrue(tabButton.waitForExistence(timeout: 6), "Missing tab: \(label)")
        tabButton.tap()
        waitForAppToSettle()
    }

    private func waitForTitle(_ title: String) {
        let navigationTitle = app.navigationBars[title]
        let staticTitle = app.staticTexts[title]

        if navigationTitle.waitForExistence(timeout: 4) || staticTitle.waitForExistence(timeout: 4) {
            waitForAppToSettle()
            return
        }

        XCTFail("Missing screen title: \(title)")
    }

    private func dismissCurrentSheet() {
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 4), "Missing Cancel button")
        cancelButton.tap()
        waitForAppToSettle()
    }

    private func scrollToAboutMe() {
        if app.staticTexts["About Me"].waitForExistence(timeout: 2) {
            return
        }

        for _ in 0..<4 {
            app.swipeUp()
            waitForAppToSettle()

            if app.staticTexts["About Me"].exists {
                return
            }
        }
    }

    private func capture(_ name: String) {
        waitForAppToSettle()

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let directory = screenshotDirectory()
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let fileURL = directory.appendingPathComponent("\(name).png")
        do {
            try screenshot.pngRepresentation.write(to: fileURL)
        } catch {
            XCTFail("Could not write screenshot \(name): \(error.localizedDescription)")
        }
    }

    private func screenshotDirectory() -> URL {
        if let path = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"],
           !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }

        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("CalorieTrackerScreenshots", isDirectory: true)
    }

    private func waitForAppToSettle() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
    }
}
