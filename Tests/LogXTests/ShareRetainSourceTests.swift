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
        XCTAssertFalse(src.contains("func logs("), src)
        let store = try source("Sources/LogX/Store.swift") + (try source("Sources/LogX/Store+Live.swift"))
        let live = try source("Sources/LogXCore/LiveStream.swift")
        XCTAssertFalse(store.contains("client.logs"), store)
        XCTAssertFalse(store.contains("client.logDetail"), store)
        XCTAssertFalse(store.contains("merge(rtdb:"), store)
        XCTAssertTrue(store.contains("AppProfile.merge(api:"), store)
        XCTAssertTrue(store.contains("LiveStreamPump.run"), store)
        XCTAssertTrue(live.contains("LiveLogDecoder.decode"), live)
        XCTAssertTrue(live.contains("log.serial?.trimmingCharacters"), live)
        XCTAssertFalse(store.contains("log.serial = log.serial ?? selectedSerial"), store)
        XCTAssertFalse(store.contains("log.serial = log.serial ?? serial"), store)
        XCTAssertFalse(store.contains("URLSession.shared"), store)
        XCTAssertTrue(live.contains("MonitorSessions.stream"), live)
        XCTAssertTrue(store.contains("while !Task.isCancelled"), store)
        let rail = try source("Sources/LogX/Views/DeviceRail.swift")
        XCTAssertFalse(rail.contains("TARMOQ"), rail)
        XCTAssertFalse(rail.contains("selectField"), rail)
    }

    func testDetailFetchConceptRemoved() throws {
        let src = try source("Sources/LogX/Store.swift")
        XCTAssertFalse(src.contains("loadDetail"), src)
        XCTAssertFalse(src.contains("selectedDetail"), src)
        XCTAssertFalse(src.contains("DetailSeq"), src)
        XCTAssertFalse(src.contains("selectedFieldId"), src)
        XCTAssertTrue(src.contains("selectedIsHidden = !cachedVisibleKeys.contains(key)"), src)
    }

    func testListHeaderContextMenuAndLiveBar() throws {
        let src = try source("Sources/LogX/Views/RequestList.swift")
        let filters = try source("Sources/LogX/Views/RequestFilterBar.swift")
        let live = try source("Sources/LogX/Views/RequestLiveBar.swift")
        XCTAssertTrue(src.contains("METOD"), src)
        XCTAssertTrue(src.contains("MANZIL"), src)
        XCTAssertTrue(src.contains("QACHON"), src)
        XCTAssertTrue(src.contains("hostLabel"), src)
        XCTAssertTrue(src.contains("RelativeTime.clock"), src)
        XCTAssertTrue(filters.contains("PATCH"), filters)
        XCTAssertTrue(filters.contains("Tozalash"), filters)
        XCTAssertTrue(live.contains("pendingWhilePausedCount"), live)
        XCTAssertTrue(live.contains("ConnectionDot"), live)
        XCTAssertTrue(src.contains("URL'ni nusxalash"), src)
        XCTAssertTrue(src.contains("cURL sifatida nusxalash"), src)
        XCTAssertTrue(filters.contains("store.errorsOnly"), filters)
        XCTAssertTrue(live.contains("oxirgisi"), live)
        XCTAssertTrue(live.contains("so'rov"), live)
        let empty = try source("Sources/LogX/Views/RequestEmptyView.swift")
        XCTAssertTrue(empty.contains("Filterga mos so'rov yo'q"), empty)
        XCTAssertTrue(src.contains("log.appShortLabel"), src)
        XCTAssertTrue(live.contains("RelativeTime.label"), live)
        XCTAssertFalse(src.contains("selectApp(\"all\") {\n                    store.selectApp"), src)
        let rail = try source("Sources/LogX/Views/DeviceRail.swift")
        XCTAssertTrue(rail.contains("ILOVALAR"), rail)
        XCTAssertTrue(rail.contains("liveApps"), rail)
        XCTAssertTrue(rail.contains("store.connection.title"), rail)
        XCTAssertTrue(rail.contains("store.connection.subtitle"), rail)
        XCTAssertTrue(rail.contains("isStreamLive(serial:"), rail)
        XCTAssertFalse(rail.contains("store.serverOK ? \"8787 · jonli\""), rail)
        XCTAssertTrue(live.contains("store.connection.title"), live)
    }
}
