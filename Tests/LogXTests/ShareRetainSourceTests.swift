import XCTest

final class ShareRetainSourceTests: XCTestCase {
    private func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    func testSharePickerIsRetainedOnHost() throws {
        let src = try source("Sources/LogX/Views/RequestDetail.swift")
        XCTAssertTrue(src.contains("class SharePickerHost"), src)
        XCTAssertTrue(src.contains("private var picker: NSSharingServicePicker?"), src)
        XCTAssertTrue(src.contains("self.picker = picker"), src)
        XCTAssertTrue(src.contains("picker.delegate = self"), src)
        XCTAssertFalse(src.contains("let picker = NSSharingServicePicker(items: [url])\n        if let view"), src)
    }

    func testPresentRetriesWhenViewMissing() throws {
        let src = try source("Sources/LogX/Views/RequestDetail.swift")
        XCTAssertFalse(src.contains("guard let view else { return }"), src)
        XCTAssertTrue(src.contains("pendingURL"), src)
        XCTAssertTrue(src.contains("flushPending()"), src)
        XCTAssertTrue(src.contains("NSApp.keyWindow?.contentView"), src)
    }

    func testDemoLogsFailureDoesNotAbortMain() throws {
        let src = try source("Sources/LogXCore/MonitorClient.swift")
        XCTAssertFalse(src.contains("/api/network-logs"), src)
        XCTAssertFalse(src.contains("/api/demo-network-logs"), src)
        XCTAssertFalse(src.contains("func logDetail"), src)
        XCTAssertTrue(src.contains("return []"), src)
        let store = try source("Sources/LogX/Store.swift")
        XCTAssertFalse(store.contains("client.logs"), store)
        XCTAssertFalse(store.contains("client.logDetail"), store)
        XCTAssertFalse(store.contains("merge(rtdb:"), store)
        XCTAssertTrue(store.contains("AppProfile.merge(api:"), store)
        XCTAssertTrue(store.contains("decodeLive(raw, serial: serial)"), store)
        XCTAssertTrue(store.contains("log.serial?.trimmingCharacters"), store)
        XCTAssertFalse(store.contains("log.serial = log.serial ?? selectedSerial"), store)
        XCTAssertFalse(store.contains("log.serial = log.serial ?? serial"), store)
        let rail = try source("Sources/LogX/Views/DeviceRail.swift")
        XCTAssertFalse(rail.contains("TARMOQ"), rail)
        XCTAssertFalse(rail.contains("selectField"), rail)
    }

    func testLoadDetailUsesDetailSeqGate() throws {
        let src = try source("Sources/LogX/Store.swift")
        XCTAssertTrue(src.contains("private var detailSeq = DetailSeq()"), src)
        XCTAssertTrue(src.contains("let seq = detailSeq.next()"), src)
        XCTAssertTrue(src.contains("detailSeq.isCurrent(seq)"), src)
        XCTAssertFalse(src.contains("detailSeq += 1"), src)
        XCTAssertFalse(src.contains("if seq == detailSeq"), src)
    }

    func testChipRailGutterIsContentMarginsNotParentPad() throws {
        let src = try source("Sources/LogX/Views/RequestList.swift")
        XCTAssertTrue(src.contains("ScrollView(.horizontal"), src)
        XCTAssertTrue(src.contains("contentMargins(.horizontal, 10, for: .scrollContent)"), src)
        XCTAssertFalse(src.contains(".padding(.horizontal, 4)"), src)
        XCTAssertTrue(src.contains(".padding(.vertical, 10)"), src)
        let filters = src.components(separatedBy: "private var filters").last ?? ""
        let beforeChipFn = filters.components(separatedBy: "private func chip").first ?? ""
        XCTAssertFalse(beforeChipFn.contains(".padding(10)"), beforeChipFn)
        XCTAssertTrue(src.contains("Filterga mos so‘rov yo‘q"), src)
        XCTAssertTrue(src.contains("log.appShortLabel"), src)
    }
}
