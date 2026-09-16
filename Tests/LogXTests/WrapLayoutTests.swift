import XCTest
@testable import LogX

final class WrapLayoutTests: XCTestCase {
    private func viewSource(_ file: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/LogX/Views/\(file)")
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testExactFitStaysOnOneLine() {
        // 100 + 6 spacing + 44 = 150 — aynan sig'adi, yorilish bo'lmasligi kerak.
        let result = WrapLayout.rects(
            items: [CGSize(width: 100, height: 20), CGSize(width: 44, height: 20)],
            maxWidth: 150, spacing: 6, lineSpacing: 6
        )
        XCTAssertEqual(result.rects.count, 2)
        XCTAssertEqual(result.rects[0].minX, 0)
        XCTAssertEqual(result.rects[1].minX, 106)
        XCTAssertEqual(result.rects[1].minY, 0)
        XCTAssertEqual(result.size, CGSize(width: 150, height: 20))
    }

    func testItemsWrapToNextLine() {
        let result = WrapLayout.rects(
            items: [CGSize(width: 100, height: 20), CGSize(width: 60, height: 16)],
            maxWidth: 150, spacing: 6, lineSpacing: 5
        )
        XCTAssertEqual(result.rects[1].minX, 0)
        XCTAssertEqual(result.rects[1].minY, 25)
        XCTAssertEqual(result.size, CGSize(width: 100, height: 41))
    }

    func testOversizedItemKeepsWidthOnOwnLine() {
        let result = WrapLayout.rects(
            items: [CGSize(width: 90, height: 20), CGSize(width: 400, height: 20), CGSize(width: 30, height: 20)],
            maxWidth: 150, spacing: 6, lineSpacing: 6
        )
        // Konteynerdan keng element siqilmaydi — o'z qatorida to'liq kenglikda turadi.
        XCTAssertEqual(result.rects[1].width, 400)
        XCTAssertEqual(result.rects[1].minY, 26)
        XCTAssertEqual(result.rects[2].minY, 52)
        XCTAssertEqual(result.size.width, 400)
        XCTAssertEqual(result.size.height, 72)
    }

    func testNilMaxWidthLaysOutSingleLine() {
        let result = WrapLayout.rects(
            items: [CGSize(width: 100, height: 20), CGSize(width: 100, height: 20)],
            maxWidth: nil, spacing: 6, lineSpacing: 6
        )
        XCTAssertEqual(result.size, CGSize(width: 206, height: 20))
        XCTAssertEqual(result.rects[1].minY, 0)
    }

    func testEmptyItemsGiveZeroSize() {
        let result = WrapLayout.rects(items: [], maxWidth: 150, spacing: 6, lineSpacing: 6)
        XCTAssertEqual(result.size, .zero)
        XCTAssertTrue(result.rects.isEmpty)
    }

    func testDetailSurfacesDegradeInsteadOfClipping() throws {
        let detail = try viewSource("RequestDetail.swift")
        XCTAssertTrue(detail.contains("ViewThatFits"), "tab/action panellar kenglikka moslashuvi bo'lishi kerak")
        XCTAssertTrue(detail.contains("WrapLayout"), "tor panelda oqim joylashuvi kerak")
        let header = try viewSource("DetailHeader.swift")
        XCTAssertTrue(header.contains("WrapLayout"), "chip qatorlari oqim bilan yotishi kerak")
        let live = try viewSource("RequestLiveBar.swift")
        XCTAssertTrue(live.contains("ViewThatFits"), "tor ro'yxatda hintlar tushib qolishi kerak")
    }
}
