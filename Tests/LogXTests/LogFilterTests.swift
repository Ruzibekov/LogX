import XCTest
@testable import LogXCore

final class LogFilterTests: XCTestCase {
    let vivo = ConnectedDevice(serial: "10AC8Z1QNJ000T6", model: "V2202", product: "vivo", preferred: true)
    let tab = ConnectedDevice(serial: "R52T", model: "SM-X216B", product: "gta4xlwifi")

    func testAppFilter_packageAndId() {
        let mahalla = NetworkLog(key: "1", packageName: "uz.realsoft.onlinemahalla.assistant")
        let ijara = NetworkLog(key: "2", packageName: "uz.realsoft.onlineijara")
        XCTAssertTrue(LogFilter.matchesApp(mahalla, appId: "all"))
        XCTAssertTrue(LogFilter.matchesApp(mahalla, appId: "mahalla"))
        XCTAssertFalse(LogFilter.matchesApp(mahalla, appId: "ijara"))
        XCTAssertTrue(LogFilter.matchesApp(ijara, appId: "ijara"))
        XCTAssertEqual(AppProfile.id(forPackage: "realsoft.cleanarea.uz"), "clean_area")
    }

    func testAppFilter_unknownPackageIsNotMahalla() {
        let log = NetworkLog(key: "x", packageName: "com.other", source: "logcat", serial: "A")
        XCTAssertEqual(log.resolvedAppId, "com.other")
        XCTAssertEqual(log.appShortLabel, "Other")
        XCTAssertFalse(LogFilter.matchesApp(log, appId: "mahalla"))
        XCTAssertTrue(LogFilter.matchesApp(log, appId: "com.other"))
        XCTAssertTrue(LogFilter.matchesApp(log, appId: "all"))
        XCTAssertEqual(
            LogFilter.apply([log], appId: "mahalla", scope: .all, status: .all, query: "").map(\.key),
            []
        )
        XCTAssertEqual(
            LogFilter.apply([log], appId: "all", scope: .all, status: .all, query: "").map(\.key),
            ["x"]
        )
    }

    func testAppFilter_emptyPackageIsUnknownNotMahalla() {
        let log = NetworkLog(key: "u", source: "logcat", serial: "A")
        XCTAssertEqual(log.resolvedAppId, AppProfile.unknownId)
        XCTAssertEqual(log.appLabel, "Noma'lum")
        XCTAssertFalse(LogFilter.matchesApp(log, appId: "mahalla"))
        XCTAssertTrue(LogFilter.matchesApp(log, appId: "unknown"))
        XCTAssertTrue(LogFilter.isLocal(log))
    }

    func testAppFilter_monitorAppIdWithoutBuiltInStays() {
        let log = NetworkLog(
            key: "f",
            packageName: "uz.foo.bar",
            source: "logcat",
            appId: "foo_bar",
            serial: "A"
        )
        XCTAssertEqual(log.resolvedAppId, "foo_bar")
        XCTAssertEqual(log.appShortLabel, "Bar")
        XCTAssertTrue(LogFilter.matchesApp(log, appId: "foo_bar"))
        XCTAssertFalse(LogFilter.matchesApp(log, appId: "mahalla"))
    }

    func testDeviceFilter_serialScope() {
        let a = NetworkLog(key: "a", serial: "10AC8Z1QNJ000T6", device: "vivo V2202")
        let b = NetworkLog(key: "b", serial: "R52T", device: "samsung SM-X216B")
        XCTAssertTrue(LogFilter.matchesDevice(a, scope: .usb(vivo)))
        XCTAssertFalse(LogFilter.matchesDevice(a, scope: .usb(tab)))
        XCTAssertTrue(LogFilter.matchesDevice(b, scope: .usb(tab)))
        XCTAssertTrue(LogFilter.matchesDevice(a, scope: .all))
    }

    func testDeviceFilter_emptySerialHiddenOnUsbScope() {
        let log = NetworkLog(key: "z")
        XCTAssertFalse(LogFilter.matchesDevice(log, scope: .usb(vivo)))
        XCTAssertTrue(LogFilter.matchesDevice(log, scope: .all))
    }

    func testResolvedScopeDropsStaleUsb() {
        let usb = ConnectedDevice(serial: "127.0.0.1:6562", model: "Phone", product: "emu")
        let live = DeviceScope.resolved(usbSerial: usb.serial, devices: [usb])
        XCTAssertEqual(live.scope, .usb(usb))
        XCTAssertEqual(live.usbSerial, usb.serial)
        XCTAssertEqual(live.scope.title, usb.title)

        let stale = DeviceScope.resolved(usbSerial: "gone", devices: [usb])
        XCTAssertEqual(stale.scope, .all)
        XCTAssertNil(stale.usbSerial)
        XCTAssertEqual(stale.scope.title, "Barcha qurilmalar")

        let none = DeviceScope.resolved(usbSerial: nil, devices: [usb])
        XCTAssertEqual(none.scope, .all)
    }

    func testUsbScopeHidesRtdbLog() {
        let usb = ConnectedDevice(serial: "127.0.0.1:6562", model: "Phone", product: "emu")
        let log = NetworkLog(
            key: "xiaomi",
            url: "https://api.online-mahalla.uz/x",
            responseCode: 400,
            device: "Xiaomi 2209116AG",
            deviceModel: "2209116AG",
            requestHeaders: ["device-id": "dev-xiaomi-1"]
        )
        XCTAssertFalse(LogFilter.matchesDevice(log, scope: .usb(usb)))
        XCTAssertTrue(LogFilter.matchesDevice(log, scope: .all))
        XCTAssertTrue(LogFilter.apply([log], appId: "all", scope: .usb(usb), status: .all, query: "").isEmpty)
        XCTAssertTrue(LogFilter.apply([log], appId: "all", scope: .all, status: .all, query: "").isEmpty)
    }

    func testStatusAndQuery() {
        let ok = NetworkLog(key: "1", method: "GET", url: "/passport/info", responseCode: 200)
        let bad = NetworkLog(key: "2", method: "POST", url: "/sessions/identify", responseCode: 400, error: "expired")
        let net = NetworkLog(key: "3", method: "GET", url: "/x")
        XCTAssertTrue(LogFilter.matchesStatus(ok, status: .ok2xx))
        XCTAssertFalse(LogFilter.matchesStatus(ok, status: .err4xx))
        XCTAssertTrue(LogFilter.matchesStatus(bad, status: .err4xx))
        XCTAssertTrue(LogFilter.matchesStatus(net, status: .net))
        XCTAssertTrue(LogFilter.matchesQuery(ok, query: "passport"))
        XCTAssertFalse(LogFilter.matchesQuery(ok, query: "identify"))
        XCTAssertTrue(LogFilter.matchesQuery(bad, query: "400"))
    }

    func testApplySortsNewestFirst() {
        let older = NetworkLog(key: "old", responseCode: 200, serial: "A", ts: 1)
        let newer = NetworkLog(key: "new", responseCode: 200, serial: "A", ts: 9)
        let out = LogFilter.apply([older, newer], appId: "all", scope: .all, status: .all, query: "")
        XCTAssertEqual(out.map { $0.key }, ["new", "old"])
    }

    func testApplyDropsRtdbEvenOnAllScope() {
        let rtdb = NetworkLog(
            key: "xiaomi",
            source: "rtdb",
            device: "Xiaomi 2209116AG"
        )
        let live = NetworkLog(key: "usb", source: "logcat", serial: "10AC8Z1QNJ000T6")
        XCTAssertFalse(LogFilter.isLocal(rtdb))
        XCTAssertTrue(LogFilter.isLocal(live))
        XCTAssertFalse(LogFilter.isLocal(NetworkLog(key: "mix", source: "rtdb", serial: "10AC8Z1QNJ000T6")))
        let out = LogFilter.apply([rtdb, live], appId: "all", scope: .all, status: .all, query: "")
        XCTAssertEqual(out.map { $0.key }, ["usb"])
    }

    func testResolveAppAliases() {
        XCTAssertEqual(AppProfile.resolveId("online-ijara"), "ijara")
        XCTAssertEqual(AppProfile.resolveId("toza"), "clean_area")
        XCTAssertEqual(AppProfile.resolveId("rsid-demo"), "rsiddemo")
        XCTAssertEqual(AppProfile.resolveId("avto-park"), "avto_park")
        XCTAssertEqual(AppProfile.resolveId("com.other"), "com.other")
        XCTAssertEqual(AppProfile.resolveId(""), AppProfile.unknownId)
        XCTAssertEqual(AppProfile.resolveId(nil), AppProfile.unknownId)
        XCTAssertEqual(AppProfile.id(forPackage: "uz.realsoft.bukhara.avtopark"), "avto_park")
    }

    func testMergeAddsLiveUnknownPackageChip() {
        let live = NetworkLog(
            key: "n",
            packageName: "uz.realsoft.new.app",
            source: "logcat",
            serial: "A"
        )
        let merged = AppProfile.merge(api: [], logs: [live])
        XCTAssertTrue(merged.contains(where: { $0.id == "mahalla" }))
        XCTAssertTrue(merged.contains(where: { $0.id == "avto_park" }))
        XCTAssertEqual(merged.first(where: { $0.id == "uz.realsoft.new.app" })?.shortLabel, "New", "generic trailing segment is skipped")
        XCTAssertFalse(merged.contains(where: { $0.id == live.resolvedAppId && $0.id == "mahalla" }))
    }

    func testQueryMatchesDiscoveredAppLabel() {
        let log = NetworkLog(key: "q", packageName: "uz.realsoft.new.app", source: "logcat", serial: "A")
        XCTAssertTrue(LogFilter.matchesQuery(log, query: "App"))
        XCTAssertTrue(LogFilter.matchesQuery(log, query: "uz.realsoft.new.app"))
    }

    func testMatchesQuery_variousFields() {
        let log = NetworkLog(
            key: "m1",
            method: "PATCH",
            url: "https://api.example.com/v1/update",
            responseCode: 422,
            error: "Validation failed",
            feature: "profile_edit",
            sessionId: "sess_987654",
            userInfoPinfl: "31234567890011"
        )
        XCTAssertTrue(LogFilter.matchesQuery(log, query: "PATCH"))
        XCTAssertTrue(LogFilter.matchesQuery(log, query: "api.example.com"))
        XCTAssertTrue(LogFilter.matchesQuery(log, query: "update"))
        XCTAssertTrue(LogFilter.matchesQuery(log, query: "422"))
        XCTAssertTrue(LogFilter.matchesQuery(log, query: "Validation"))
        XCTAssertTrue(LogFilter.matchesQuery(log, query: "profile_edit"))
        XCTAssertTrue(LogFilter.matchesQuery(log, query: "sess_987654"))
        XCTAssertTrue(LogFilter.matchesQuery(log, query: "31234567890011"))
        XCTAssertFalse(LogFilter.matchesQuery(log, query: "nonexistent_token"))
    }
}
