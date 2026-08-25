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

    func testLoadDetailUsesDetailSeqGate() throws {
        let src = try source("Sources/LogX/Store.swift")
        XCTAssertTrue(src.contains("private var detailSeq = DetailSeq()"), src)
        XCTAssertTrue(src.contains("let seq = detailSeq.next()"), src)
        XCTAssertTrue(src.contains("detailSeq.isCurrent(seq)"), src)
        XCTAssertFalse(src.contains("detailSeq += 1"), src)
        XCTAssertFalse(src.contains("if seq == detailSeq"), src)
    }

    func testListHeaderContextMenuAndLiveBar() throws {
        let src = try source("Sources/LogX/Views/RequestList.swift")
        // Ustun sarlavhalari — fixed-slot lane’lar
        XCTAssertTrue(src.contains("METOD"), src)
        XCTAssertTrue(src.contains("MANZIL"), src)
        XCTAssertTrue(src.contains("QACHON"), src)
        XCTAssertTrue(src.contains("hostLabel"), src)
        XCTAssertTrue(src.contains("RelativeTime.clock"), src)
        XCTAssertTrue(src.contains("PATCH"), src)
        XCTAssertTrue(src.contains("Tozalash"), src)
        XCTAssertTrue(src.contains("skippedWhilePaused"), src)
        XCTAssertTrue(src.contains("ConnectionDot"), src)
        // Kontekst menyu — cURL bilan
        XCTAssertTrue(src.contains("URL'ni nusxalash"), src)
        XCTAssertTrue(src.contains("cURL sifatida nusxalash"), src)
        // Xato-birinchi filtr + live-bar
        XCTAssertTrue(src.contains("store.errorsOnly"), src)
        XCTAssertTrue(src.contains("oxirgisi"), src)
        XCTAssertTrue(src.contains("so'rov"), src)
        let empty = try source("Sources/LogX/Views/RequestEmptyView.swift")
        XCTAssertTrue(empty.contains("Filterga mos so'rov yo'q"), empty)
        XCTAssertTrue(src.contains("log.appShortLabel"), src)
        XCTAssertTrue(src.contains("RelativeTime.label"), src)
        // Ilova filtri endi sidebar’da — RequestList’da app-chip relka yo’q
        XCTAssertFalse(src.contains("selectApp(\"all\") {\n                    store.selectApp"), src)
        let rail = try source("Sources/LogX/Views/DeviceRail.swift")
        XCTAssertTrue(rail.contains("ILLOVALAR"), rail)
        XCTAssertTrue(rail.contains("liveApps"), rail)
        XCTAssertTrue(rail.contains("store.connection.title"), rail)
        XCTAssertTrue(rail.contains("store.connection.subtitle"), rail)
        XCTAssertTrue(rail.contains("isStreamLive(serial:"), rail)
        XCTAssertFalse(rail.contains("store.serverOK ? \"8787 · jonli\""), rail)
        XCTAssertTrue(src.contains("store.connection.title"), src)
    }
}
