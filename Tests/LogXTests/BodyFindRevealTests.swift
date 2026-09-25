import XCTest
import AppKit
import LogXCore
@testable import LogX

@MainActor
final class BodyFindRevealTests: XCTestCase {
    private func key(_ logKey: String = "a", tab: DetailTab = .request, query: String = "", index: Int = 0, fontSize: CGFloat = 11.5) -> RenderedBody.Key {
        RenderedBody.Key(logKey: logKey, tab: tab, redact: false, pretty: true, query: query, index: index, tree: false, fontSize: fontSize)
    }

    private func body(_ key: RenderedBody.Key) -> RenderedBody {
        RenderedBody(key: key, text: "{}", attributed: NSAttributedString(string: "{}"), matchCount: 0, activeRange: nil, truncationNotice: nil)
    }

    func testPreviousBodyStaysOnScreenWhileFindQueryIsTyped() {
        let cached = body(key(query: "stre"))
        XCTAssertNotNil(RenderedBody.displayable(cached, for: key(query: "street")))
        XCTAssertNotNil(RenderedBody.displayable(cached, for: key(query: "stre", index: 3)))
        XCTAssertNotNil(RenderedBody.displayable(cached, for: key(query: "stre", fontSize: 14)))
    }

    func testOtherLogOrTabIsNotShownFromStaleCache() {
        let cached = body(key(query: "stre"))
        XCTAssertNil(RenderedBody.displayable(cached, for: key("b", query: "stre")))
        XCTAssertNil(RenderedBody.displayable(cached, for: key(tab: .response, query: "stre")))
        XCTAssertNil(RenderedBody.displayable(nil, for: key()))
    }

    private func lines(_ count: Int) -> String {
        (0..<count).map { "\"field_\($0)\" : \($0)," }.joined(separator: "\n")
    }

    private func container() -> (BodyContainerView, BodyTextView.Coordinator) {
        let view = BodyTextView.makeContainer(fontSize: 11.5)
        view.frame = NSRect(x: 0, y: 0, width: 420, height: 200)
        view.layoutSubtreeIfNeeded()
        let coord = BodyTextView.Coordinator()
        coord.observe(scroll: view.scroll, gutter: view.gutter)
        return (view, coord)
    }

    private func activeRange(in text: String, of needle: String) -> NSRange {
        (text as NSString).range(of: needle)
    }

    private func matchRect(_ view: BodyContainerView, _ range: NSRange) -> NSRect {
        let textView = view.scroll.documentView as! NSTextView
        let lm = textView.layoutManager!
        let glyphs = lm.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        return lm.boundingRect(forGlyphRange: glyphs, in: textView.textContainer!)
            .offsetBy(dx: textView.textContainerOrigin.x, dy: textView.textContainerOrigin.y)
    }

    func testTypingFindScrollsActiveMatchToViewportCenter() {
        let (view, coord) = container()
        let text = lines(400)
        let range = activeRange(in: text, of: "\"field_300\"")
        coord.apply(to: view, text: NSAttributedString(string: text), wrap: false, activeRange: range, fontSize: 11.5, contentID: "a", animate: false)
        let visible = view.scroll.contentView.bounds
        let rect = matchRect(view, range)
        XCTAssertTrue(visible.intersects(rect), "topilma ko'rinmayapti: \(visible) \(rect)")
        XCTAssertEqual(visible.midY, rect.midY, accuracy: 20, "topilma markazga olib kelinmadi")
    }

    func testMatchInFreshlyCreatedBodyIsCenteredAfterFirstLayout() {
        let view = BodyTextView.makeContainer(fontSize: 11.5)
        let coord = BodyTextView.Coordinator()
        coord.observe(scroll: view.scroll, gutter: view.gutter)
        let text = lines(400)
        let range = activeRange(in: text, of: "\"field_300\"")
        coord.apply(to: view, text: NSAttributedString(string: text), wrap: false, activeRange: range, fontSize: 11.5, contentID: "a", animate: false)
        view.frame = NSRect(x: 0, y: 0, width: 420, height: 200)
        view.layoutSubtreeIfNeeded()
        let visible = view.scroll.contentView.bounds
        let rect = matchRect(view, range)
        XCTAssertTrue(visible.contains(rect), "yangi ochilgan tanada topilma to'liq ko'rinmayapti: \(visible) \(rect)")
        XCTAssertEqual(visible.midY, rect.midY, accuracy: 20)
    }

    func testZoomKeepsActiveMatchCentered() {
        let (view, coord) = container()
        let text = lines(400)
        let range = activeRange(in: text, of: "\"field_300\"")
        coord.apply(to: view, text: NSAttributedString(string: text), wrap: false, activeRange: range, fontSize: 11.5, contentID: "a", animate: false)
        let bigger = NSAttributedString(string: text, attributes: [.font: NSFont.monospacedSystemFont(ofSize: 20, weight: .regular)])
        coord.apply(to: view, text: bigger, wrap: false, activeRange: range, fontSize: 20, contentID: "a", animate: false)
        let visible = view.scroll.contentView.bounds
        XCTAssertEqual(visible.midY, matchRect(view, range).midY, accuracy: 20, "zoomdan keyin topilma markazda qolmadi")
    }

    func testMatchNearTopDoesNotLayOutWholeLargeBody() {
        let (view, coord) = container()
        let text = lines(12_000)
        let range = activeRange(in: text, of: "\"field_40\"")
        coord.apply(to: view, text: NSAttributedString(string: text), wrap: false, activeRange: range, fontSize: 11.5, contentID: "a", animate: false)
        let textView = view.scroll.documentView as! NSTextView
        XCTAssertLessThan(textView.layoutManager!.firstUnlaidCharacterIndex(), (text as NSString).length, "har harfda butun katta tana layout qilinmasligi kerak")
        XCTAssertTrue(view.scroll.contentView.bounds.intersects(matchRect(view, range)))
    }

    func testNoMatchWhileTypingKeepsScrollPosition() {
        let (view, coord) = container()
        let text = lines(400)
        let range = activeRange(in: text, of: "\"field_300\"")
        coord.apply(to: view, text: NSAttributedString(string: text), wrap: false, activeRange: range, fontSize: 11.5, contentID: "a", animate: false)
        let before = view.scroll.contentView.bounds.origin
        XCTAssertGreaterThan(before.y, 0)
        coord.apply(to: view, text: NSAttributedString(string: text), wrap: false, activeRange: nil, fontSize: 11.5, contentID: "a", animate: false)
        XCTAssertEqual(view.scroll.contentView.bounds.origin.y, before.y, accuracy: 0.5, "qidiruv matnida topilma yo'q bo'lsa tana tepaga sakramasligi kerak")
    }

    func testNewContentStartsFromTop() {
        let (view, coord) = container()
        let text = lines(400)
        let range = activeRange(in: text, of: "\"field_300\"")
        coord.apply(to: view, text: NSAttributedString(string: text), wrap: false, activeRange: range, fontSize: 11.5, contentID: "a", animate: false)
        coord.apply(to: view, text: NSAttributedString(string: text), wrap: false, activeRange: nil, fontSize: 11.5, contentID: "b", animate: false)
        XCTAssertEqual(view.scroll.contentView.bounds.origin.y, 0, accuracy: 0.5)
    }

    func testCenteredOriginClampsToDocumentEdges() {
        let viewport = NSSize(width: 400, height: 200)
        let document = NSSize(width: 400, height: 1000)
        let top = BodyTextView.centeredOrigin(target: NSRect(x: 10, y: 5, width: 40, height: 14), viewport: viewport, document: document, current: NSPoint(x: 0, y: 500))
        XCTAssertEqual(top.y, 0)
        let bottom = BodyTextView.centeredOrigin(target: NSRect(x: 10, y: 990, width: 40, height: 10), viewport: viewport, document: document, current: .zero)
        XCTAssertEqual(bottom.y, 800)
        let middle = BodyTextView.centeredOrigin(target: NSRect(x: 10, y: 500, width: 40, height: 20), viewport: viewport, document: document, current: .zero)
        XCTAssertEqual(middle.y, 410)
    }

    func testCenteredOriginRevealsMatchBeyondRightEdge() {
        let viewport = NSSize(width: 400, height: 200)
        let document = NSSize(width: 2000, height: 1000)
        let visible = BodyTextView.centeredOrigin(target: NSRect(x: 100, y: 500, width: 40, height: 20), viewport: viewport, document: document, current: .zero)
        XCTAssertEqual(visible.x, 0)
        let far = BodyTextView.centeredOrigin(target: NSRect(x: 1500, y: 500, width: 40, height: 20), viewport: viewport, document: document, current: .zero)
        XCTAssertLessThanOrEqual(far.x, 1500)
        XCTAssertGreaterThanOrEqual(far.x + viewport.width, 1540)
    }
}

@MainActor
final class FindCountImmediateTests: XCTestCase {
    private func key(_ logKey: String = "a", query: String, index: Int = 0) -> RenderedBody.Key {
        RenderedBody.Key(logKey: logKey, tab: .request, redact: false, pretty: true, query: query, index: index, tree: false)
    }

    private let json = "{\n  \"street\" : \"Navoiy\",\n  \"streets\" : [\"street A\", \"Street B\"],\n  \"city\" : \"Toshkent\"\n}"

    private func rendered(query: String) -> RenderedBody {
        RenderedBody.make(log: NetworkLog(key: "a", method: "POST", url: "https://x.uz/a", api: "/a", requestBody: json), key: key(query: query))
    }

    func testCountForNewQueryComesFromCachedBodyWithoutWaitingForRender() {
        let stale = rendered(query: "stre")
        XCTAssertEqual(stale.matchCount, 4)
        let snapshot = FindCount.snapshot(from: stale, for: key(query: "street"))
        XCTAssertEqual(snapshot?.value, 4)
        XCTAssertEqual(FindCount.snapshot(from: stale, for: key(query: "streets"))?.value, 1)
        XCTAssertEqual(FindCount.snapshot(from: stale, for: key(query: "zzz"))?.value, 0)
        XCTAssertEqual(FindCount.snapshot(from: stale, for: key(query: "  "))?.value, 0)
    }

    func testImmediateCountMatchesFullRenderCount() {
        let stale = rendered(query: "")
        for query in ["s", "st", "Street", "city", "\"", "Navoiy\","] {
            XCTAssertEqual(FindCount.snapshot(from: stale, for: key(query: query))?.value, rendered(query: query).matchCount, query)
        }
    }

    func testCountFromOtherLogIsNotReused() {
        XCTAssertNil(FindCount.snapshot(from: rendered(query: "stre"), for: key("b", query: "street")))
        XCTAssertNil(FindCount.snapshot(from: nil, for: key(query: "street")))
    }

    func testDisplayedCountPrefersFreshSnapshotOverStaleRender() {
        let stale = rendered(query: "stre")
        let snapshot = FindCount.snapshot(from: stale, for: key(query: "streets"))
        XCTAssertEqual(FindCount.display(rendered: stale, snapshot: snapshot, query: "streets"), 1)
        XCTAssertEqual(FindCount.display(rendered: stale, snapshot: snapshot, query: "stre"), 4)
        XCTAssertEqual(FindCount.display(rendered: stale, snapshot: nil, query: "streets"), 4)
        XCTAssertEqual(FindCount.display(rendered: nil, snapshot: snapshot, query: "streets"), 0)
    }

    func testCountOnLargeBodyIsFastEnoughForKeystroke() {
        let big = (0..<11_000).map { "\"street_\($0)\" : \"value \($0)\"," }.joined(separator: "\n")
        XCTAssertEqual(JSONFind.count(big, query: "street_1"), (0..<11_000).filter { String($0).hasPrefix("1") }.count)
        let start = Date()
        _ = JSONFind.count(big, query: "value")
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.1)
    }
}
