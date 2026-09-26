import XCTest
import SwiftUI
import AppKit
import LogXCore
@testable import LogX

@MainActor
final class TreeFindTests: XCTestCase {
    final class Model: ObservableObject {
        @Published var query = ""
        @Published var index = 0
        @Published var count = -1
    }

    struct Host: View {
        let tree: JSONTree
        @ObservedObject var model: Model
        var body: some View {
            JSONTreeView(tree: tree, query: model.query, activeIndex: model.index) { model.count = $0 }
        }
    }

    private func spin(_ seconds: Double = 0.5) { RunLoop.current.run(until: Date().addingTimeInterval(seconds)) }

    private func scrollView(in view: NSView) -> NSScrollView? {
        if let found = view as? NSScrollView { return found }
        for sub in view.subviews { if let found = scrollView(in: sub) { return found } }
        return nil
    }

    private func items(_ count: Int) -> String {
        "{\"data\": {\"items\": [" + (0..<count).map { "{\"id\": \($0), \"addr\": {\"geo\": {\"street\": \"s\($0)x\"}}}" }.joined(separator: ",") + "]}}"
    }

    private func window(_ tree: JSONTree, _ model: Model) -> (NSWindow, NSScrollView?) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: Host(tree: tree, model: model).environmentObject(LogStore()))
        window.contentView = host
        window.orderFrontRegardless()
        spin()
        return (window, scrollView(in: host))
    }

    func testTypingInTreeScrollsToMatchInCollapsedBranchAndCountsImmediately() throws {
        let tree = try XCTUnwrap(JSONTree(text: items(300), identity: "t1"))
        let model = Model()
        let (win, found) = window(tree, model)
        defer { win.close() }
        let scroll = try XCTUnwrap(found)
        XCTAssertEqual(scroll.contentView.bounds.origin.y, 0)
        model.query = "s250x"
        spin(0.05)
        XCTAssertEqual(model.count, 1, "daraxtda topilmalar soni darhol yangilanishi kerak")
        spin()
        let far = scroll.contentView.bounds.origin.y
        XCTAssertGreaterThan(far, 3000, "yig'iq shoxdagi topilmaga scroll qilinmadi")
        model.query = "s10x"
        spin()
        XCTAssertLessThan(scroll.contentView.bounds.origin.y, far)
        XCTAssertGreaterThan(scroll.contentView.bounds.origin.y, 0)
    }

    func testTreeOpenedWithQueryStartsAtMatch() throws {
        let tree = try XCTUnwrap(JSONTree(text: items(300), identity: "t2"))
        let model = Model()
        model.query = "s250x"
        let (win, found) = window(tree, model)
        defer { win.close() }
        XCTAssertEqual(model.count, 1)
        XCTAssertGreaterThan(try XCTUnwrap(found).contentView.bounds.origin.y, 3000)
    }

    func testTreeFindRenders() throws {
        let tree = try XCTUnwrap(JSONTree(text: items(40), identity: "t4"))
        let model = Model()
        model.query = "s2"
        model.index = 1
        let (win, _) = window(tree, model)
        defer { win.close() }
        let host = try XCTUnwrap(win.contentView)
        let rep = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".screenshots")
        try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("render-tree-find.png"))
        XCTAssertEqual(model.count, 11)
    }

    func testTreeMatchesAreComputedOncePerQuery() throws {
        let tree = try XCTUnwrap(JSONTree(text: items(50), identity: "t3"))
        let finder = TreeFinder()
        let first = finder.matches(in: tree, query: "s1")
        XCTAssertEqual(finder.matches(in: tree, query: "s1"), first)
        XCTAssertEqual(finder.computations, 1)
        XCTAssertEqual(finder.matches(in: tree, query: "s12").count, 1)
        XCTAssertEqual(finder.computations, 2)
        XCTAssertEqual(first, tree.matches(query: "s1"))
    }

    func testMatchedTextInTreeRowIsHighlighted() {
        let active = TreeFindHighlight.text("\"Navoiy street\"", query: " STREET ", active: true)
        let runs = active.runs.filter { $0.backgroundColor != nil }
        XCTAssertEqual(runs.count, 1)
        XCTAssertEqual(runs.first.map { String(active[$0.range].characters) }, "street")
        XCTAssertEqual(runs.first?.backgroundColor, TreeFindHighlight.activeBackground)
        let matched = TreeFindHighlight.text("street / Street", query: "street", active: false)
        let matchedRuns = matched.runs.filter { $0.backgroundColor != nil }
        XCTAssertEqual(matchedRuns.count, 2)
        XCTAssertTrue(matchedRuns.allSatisfy { $0.backgroundColor == TreeFindHighlight.matchBackground })
        XCTAssertTrue(TreeFindHighlight.text("city", query: "street", active: false).runs.allSatisfy { $0.backgroundColor == nil })
        XCTAssertTrue(TreeFindHighlight.text("street", query: "", active: false).runs.allSatisfy { $0.backgroundColor == nil })
    }

    func testIndicatorShowsOnlyMatchedTextInBrightYellow() throws {
        let indicator = try XCTUnwrap(TreeFindHighlight.indicator("\"Navoiy street\"", query: "Street"))
        let visible = indicator.runs.filter { $0.foregroundColor != .clear }
        XCTAssertEqual(visible.count, 1)
        XCTAssertEqual(visible.first.map { String(indicator[$0.range].characters) }, "street")
        XCTAssertEqual(visible.first?.backgroundColor, TreeFindHighlight.indicatorBackground)
        XCTAssertEqual(String(indicator.characters), "\"Navoiy street\"", "overlay matn qator bilan bir xil joylashishi uchun to'liq qoladi")
        XCTAssertNil(TreeFindHighlight.indicator("city", query: "street"))
        XCTAssertNil(TreeFindHighlight.indicator("street", query: " "))
    }

    func testActiveRowShowsYellowFindIndicatorAfterReveal() throws {
        let tree = try XCTUnwrap(JSONTree(text: items(300), identity: "t5"))
        let model = Model()
        let (win, _) = window(tree, model)
        defer { win.close() }
        let host = try XCTUnwrap(win.contentView)
        func yellowPixels() -> Int {
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return 0 }
            host.cacheDisplay(in: host.bounds, to: rep)
            var total = 0
            for y in stride(from: 0, to: rep.pixelsHigh, by: 2) {
                for x in stride(from: 0, to: rep.pixelsWide, by: 2) {
                    guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                    if c.redComponent > 0.92, c.greenComponent > 0.82, c.blueComponent < 0.45 { total += 1 }
                }
            }
            return total
        }
        XCTAssertEqual(yellowPixels(), 0)
        model.query = "s250x"
        var shown = 0
        let deadline = Date().addingTimeInterval(1.5)
        repeat {
            spin(0.05)
            shown = yellowPixels()
        } while shown <= 20 && Date() < deadline
        if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
            host.cacheDisplay(in: host.bounds, to: rep)
            let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".screenshots")
            try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("render-tree-find-indicator.png"))
        }
        XCTAssertGreaterThan(shown, 20, "faol topilmada sariq find belgisi ko'rinmadi")
        spin(1.6)
        XCTAssertEqual(yellowPixels(), 0, "find belgisi o'zi so'nishi kerak")
    }
}
