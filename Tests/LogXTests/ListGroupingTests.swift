import XCTest
@testable import LogXCore

final class ListGroupingTests: XCTestCase {
    private func log(_ key: String, _ url: String) -> NetworkLog {
        NetworkLog(key: key, method: "GET", url: url, api: url, responseCode: 200, durationMs: 10, ts: 1)
    }

    func testEmptyGivesNoRows() {
        XCTAssertTrue(ListGrouping.rows([]).isEmpty)
    }

    func testOneHostGetsOneHeaderWithTheCount() {
        let rows = ListGrouping.rows([log("a", "https://api.uz/1"), log("b", "https://api.uz/2")])
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows.first, .host(name: "api.uz", count: 2))
    }

    func testHeaderAppearsWhenTheHostChanges() {
        let rows = ListGrouping.rows([
            log("a", "https://api.uz/1"),
            log("b", "https://cdn.uz/x.png"),
            log("c", "https://cdn.uz/y.png"),
        ])
        let headers = rows.compactMap { row -> (String, Int)? in
            if case let .host(name, count) = row { return (name, count) }
            return nil
        }
        XCTAssertEqual(headers.map(\.0), ["api.uz", "cdn.uz"])
        XCTAssertEqual(headers.map(\.1), [1, 2])
    }

    func testSameHostReturningLaterGetsItsOwnHeader() {
        let rows = ListGrouping.rows([
            log("a", "https://api.uz/1"),
            log("b", "https://cdn.uz/x"),
            log("c", "https://api.uz/2"),
        ])
        XCTAssertEqual(rows.count, 6)
        XCTAssertEqual(rows.compactMap { if case let .host(name, _) = $0 { return name } else { return nil } }, ["api.uz", "cdn.uz", "api.uz"])
    }

    func testLogOrderIsNeverChanged() {
        let logs = [log("a", "https://api.uz/1"), log("b", "https://cdn.uz/x"), log("c", "https://api.uz/2")]
        let keys = ListGrouping.rows(logs).compactMap { if case let .log(l) = $0 { return l.key } else { return nil } }
        XCTAssertEqual(keys, ["a", "b", "c"])
    }

    func testHostlessLogsGetNoHeader() {
        let rows = ListGrouping.rows([log("a", "")])
        XCTAssertEqual(rows.count, 1)
        if case .log = rows[0] {} else { XCTFail("faqat log qatori kutilgan") }
    }
}
