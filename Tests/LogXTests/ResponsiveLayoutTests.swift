import XCTest
@testable import LogXCore
@testable import LogX

final class ResponsiveLayoutTests: XCTestCase {
    private func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    func testListColumnResponsiveRules() {
        // Rule 1: App column visibility
        func shouldShowAppColumn(selectedAppId: String, width: CGFloat) -> Bool {
            selectedAppId == "all" && width >= 520
        }

        // When a specific app is selected, app column is never shown (saves 76pt space)
        XCTAssertFalse(shouldShowAppColumn(selectedAppId: "uz.mahalla.app", width: 600))
        XCTAssertFalse(shouldShowAppColumn(selectedAppId: "uz.mahalla.app", width: 360))

        // When all apps are selected:
        // On narrow widths (< 520pt), app column is hidden to make room for path
        XCTAssertFalse(shouldShowAppColumn(selectedAppId: "all", width: 360))
        XCTAssertFalse(shouldShowAppColumn(selectedAppId: "all", width: 480))
        XCTAssertFalse(shouldShowAppColumn(selectedAppId: "all", width: 519))
        // On wide widths (>= 520pt), app column is shown
        XCTAssertTrue(shouldShowAppColumn(selectedAppId: "all", width: 520))
        XCTAssertTrue(shouldShowAppColumn(selectedAppId: "all", width: 700))

        // Rule 2: Time column visibility
        func shouldShowTimeColumn(width: CGFloat) -> Bool {
            width >= 430
        }

        // On very narrow list width (< 430pt), time column is hidden
        XCTAssertFalse(shouldShowTimeColumn(width: 360))
        XCTAssertFalse(shouldShowTimeColumn(width: 420))
        // On normal width, time column is visible
        XCTAssertTrue(shouldShowTimeColumn(width: 430))
        XCTAssertTrue(shouldShowTimeColumn(width: 560))
    }

    func testRequestListContainsAdaptiveWidthTracking() throws {
        let src = try source("Sources/LogX/Views/RequestList.swift")
        XCTAssertTrue(src.contains("showAppColumn"), src)
        XCTAssertTrue(src.contains("showTimeColumn"), src)
        XCTAssertTrue(src.contains("RequestListWidthKey"), src)
        XCTAssertTrue(src.contains("listWidth"), src)
    }

    func testRequestRowAdaptsToNarrowWidths() throws {
        let src = try source("Sources/LogX/Views/RequestRow.swift")
        XCTAssertTrue(src.contains("var showAppColumn: Bool"), src)
        XCTAssertTrue(src.contains("var showTimeColumn: Bool"), src)
        XCTAssertTrue(src.contains("if showTimeColumn"), src)
        XCTAssertTrue(src.contains("if showAppColumn"), src)
    }

    func testDetailHeaderStructureSeparatesHeaderAndMetadata() throws {
        let src = try source("Sources/LogX/Views/DetailHeader.swift")
        XCTAssertTrue(src.contains("HeaderIconButton"), src)
        XCTAssertTrue(src.contains("isCollapsed"), src)
        XCTAssertTrue(src.contains("WrapLayout"), src)
        XCTAssertTrue(src.contains("problemMessage"), src)
    }

    func testParamRowViewHasFlexibleBounds() throws {
        let src = try source("Sources/LogX/Views/ParamRowView.swift")
        XCTAssertTrue(src.contains("minWidth: 90"), src)
        XCTAssertTrue(src.contains("idealWidth: 130"), src)
        XCTAssertTrue(src.contains("maxWidth: 200"), src)
        XCTAssertTrue(src.contains("maxWidth: .infinity, alignment: .leading"), src)
    }

    func testDiffViewHasCompactMinimumBounds() throws {
        let src = try source("Sources/LogX/Views/DiffView.swift")
        XCTAssertTrue(src.contains("minWidth: 720"), src)
        XCTAssertTrue(src.contains("minHeight: 480"), src)
    }

    func testReplayComposerViewFlexibleHeaders() throws {
        let src = try source("Sources/LogX/Views/ReplayComposerView.swift")
        XCTAssertTrue(src.contains("minWidth: 160"), src)
        XCTAssertTrue(src.contains("idealWidth: 200"), src)
        XCTAssertTrue(src.contains("maxWidth: 240"), src)
    }
}
