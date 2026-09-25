import XCTest
@testable import LogXCore

final class InspectorSurfaceTests: XCTestCase {
    private func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    func testFilterChipsDoNotWrap() throws {
        let filters = try source("Sources/LogX/Views/RequestFilterBar.swift")
        XCTAssertTrue(filters.contains("lineLimit(1)"), filters)
        XCTAssertTrue(filters.contains("fixedSize"), filters)
        XCTAssertTrue(filters.contains("LogXPressStyle"), filters)
        XCTAssertTrue(filters.contains("statusChip"), filters)
        XCTAssertFalse(filters.contains("shortcutBadge"), filters)
    }

    func testShortcutsUseSFSymbolsNotMonoCommand() throws {
        let live = try source("Sources/LogX/Views/RequestLiveBar.swift")
        let glyph = try source("Sources/LogX/Views/ShortcutGlyph.swift")
        XCTAssertTrue(live.contains("command"), live)
        XCTAssertTrue(live.contains("ko'rinadi"), live)
        XCTAssertTrue(glyph.contains("systemName"), glyph)
        XCTAssertTrue(glyph.contains("LogXPressStyle"), glyph)
        XCTAssertFalse(live.contains("shortcutBadge(\"⌘F\")"), live)
    }

    func testJSONHighlighterDoesNotClipViaNSAttributedString() throws {
        let hl = try source("Sources/LogX/Views/JSONHighlighter.swift")
        XCTAssertTrue(hl.contains("static func nsAttributedString("), hl)
        XCTAssertTrue(hl.contains("activeRange"), hl)
        XCTAssertTrue(hl.contains("AttributedString()"), hl)
        XCTAssertTrue(hl.contains("120_000"), hl)
        XCTAssertTrue(hl.contains("highlights"), hl)
        let detail = try source("Sources/LogX/Views/RequestDetail.swift") + (try source("Sources/LogX/Views/BodyTextView.swift")) + (try source("Sources/LogX/Views/BodyTextView+Reveal.swift"))
        XCTAssertTrue(detail.contains("BodyTextView"), detail)
        XCTAssertTrue(detail.contains("centeredOrigin"), detail)
        XCTAssertTrue(detail.contains("@AppStorage(\"logx.wrapBody\") private var wrapBody = false"), "long lines scroll horizontally by default")
        XCTAssertTrue(detail.contains("lineBreakMode = .byClipping"), detail)
        XCTAssertTrue(detail.contains("Tokenlar"), detail)
        XCTAssertFalse(detail.contains("Yashirish"), detail)
    }

    func testSearchPromptFitsToolbar() throws {
        let filters = try source("Sources/LogX/Views/RequestFilterBar.swift")
        XCTAssertTrue(filters.contains("Host, URL, sarlavha, tana"), filters)
        XCTAssertTrue(filters.contains("Text(\"⌘F\")"), filters)
        let content = try source("Sources/LogX/Views/ContentView.swift")
        XCTAssertFalse(content.contains(".searchable("), content)
    }

    func testSidebarToggleDoesNotLockLayout() throws {
        let content = try source("Sources/LogX/Views/ContentView.swift")
        XCTAssertTrue(content.contains("HSplitView"), content)
        XCTAssertTrue(content.contains("minWidth: 380, idealWidth: 460"), content)
        XCTAssertTrue(content.contains("minWidth: 460, maxWidth: .infinity"), content)
        XCTAssertTrue(content.contains("logx.sidebarVisible"), content)
        XCTAssertFalse(content.contains("max: 920"), content)
        XCTAssertFalse(content.contains("max: 680"), content)
        let rail = try source("Sources/LogX/Views/DeviceRail.swift")
        XCTAssertTrue(rail.contains("maxHeight: .infinity"), rail)
        XCTAssertTrue(rail.contains(".frame(width: Self.width)"), rail)
        let app = try source("Sources/LogX/LogXApp.swift")
        XCTAssertTrue(app.contains("width: 960"), app)
        XCTAssertFalse(app.contains("width: 1100"), app)
    }

    func testAppSwitchDoesNotDiffWholeList() throws {
        let store = try source("Sources/LogX/Store.swift")
        XCTAssertTrue(store.contains("guard selectedAppId != id"), store)
        let list = try source("Sources/LogX/Views/RequestList.swift")
        XCTAssertTrue(list.contains("listScope"), list)
        XCTAssertTrue(list.contains(".id(listScope)"), list)
        XCTAssertTrue(list.contains("selectedAppId"), list)
        let detail = try source("Sources/LogX/Views/RequestDetail.swift")
        XCTAssertFalse(detail.contains("value: store.selectedKey"), detail)
        XCTAssertFalse(detail.contains(".transition(.opacity)"), detail)
        let rail = try source("Sources/LogX/Views/DeviceRail.swift")
        XCTAssertTrue(rail.contains("disablesAnimations"), rail)
        XCTAssertTrue(rail.contains("setScope"), rail)
    }

    func testCommandFJSONFindRouting() throws {
        let app = try source("Sources/LogX/LogXApp.swift")
        XCTAssertTrue(app.contains("add(findMenu, \"JSON ichida topish\", #selector(focusDetailFind(_:)), \"f\", .command, target: self)"), app)
        XCTAssertTrue(app.contains("add(findMenu, \"So'rovlarni qidirish\", #selector(focusListSearch(_:)), \"f\", [.command, .shift], target: self)"), app)
        XCTAssertTrue(app.contains("if store?.selectedLog != nil"), app)
        XCTAssertTrue(app.contains("NotificationCenter.default.post(name: LogXNotice.focusDetailFind, object: nil)"), app)
        XCTAssertTrue(app.contains("focusListSearch(sender)"), app)
        let findBar = try source("Sources/LogX/Views/DetailFindBar.swift")
        XCTAssertTrue(findBar.contains("Tana ichida qidirish"), findBar)
        XCTAssertTrue(findBar.contains("accessibilityLabel(\"JSON ichida topish\")"), findBar)
    }
}
