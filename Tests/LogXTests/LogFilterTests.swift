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

    func testAppFilter_unknownPackageStaysMahalla() {
        let log = NetworkLog(key: "x", packageName: "com.other")
        XCTAssertEqual(log.resolvedAppId, "mahalla")
        XCTAssertTrue(LogFilter.matchesApp(log, appId: "mahalla"))
    }

    func testDeviceFilter_modelAndSerial() {
        let a = NetworkLog(key: "a", serial: "10AC8Z1QNJ000T6", device: "vivo V2202")
        let b = NetworkLog(key: "b", device: "samsung SM-X216B")
        XCTAssertTrue(LogFilter.matchesDevice(a, device: vivo))
        XCTAssertFalse(LogFilter.matchesDevice(a, device: tab))
        XCTAssertFalse(LogFilter.matchesDevice(b, device: tab))
        XCTAssertTrue(LogFilter.matchesDevice(b, scope: .field(FieldDevice(id: "samsung sm-x216b", label: "samsung SM-X216B", count: 1))))
        XCTAssertTrue(LogFilter.matchesDevice(a, device: nil))
    }

    func testDeviceFilter_emptyDeviceFieldKeepsRow() {
        let log = NetworkLog(key: "z")
        XCTAssertFalse(LogFilter.matchesDevice(log, device: vivo))
        XCTAssertTrue(LogFilter.matchesDevice(log, scope: .all))
    }

    func testResolvedScopeDropsStaleFieldAndPrefersLiveUsb() {
        let usb = ConnectedDevice(serial: "127.0.0.1:6562", model: "Phone", product: "emu")
        let xiaomi = FieldDevice(id: "dev-xiaomi-1", label: "Xiaomi 2209116AG", count: 8)
        let live = DeviceScope.resolved(
            usbSerial: usb.serial, fieldId: xiaomi.id, devices: [usb], fields: [xiaomi]
        )
        XCTAssertEqual(live.scope, .usb(usb))
        XCTAssertEqual(live.usbSerial, usb.serial)
        XCTAssertNil(live.fieldId)
        XCTAssertEqual(live.scope.title, usb.title)

        let field = DeviceScope.resolved(
            usbSerial: nil, fieldId: xiaomi.id, devices: [usb], fields: [xiaomi]
        )
        XCTAssertEqual(field.scope, .field(xiaomi))
        XCTAssertEqual(field.scope.title, "Xiaomi 2209116AG")

        let stale = DeviceScope.resolved(
            usbSerial: "gone", fieldId: "missing", devices: [usb], fields: [xiaomi]
        )
        XCTAssertEqual(stale.scope, .all)
        XCTAssertNil(stale.usbSerial)
        XCTAssertNil(stale.fieldId)
        XCTAssertEqual(stale.scope.title, "Barcha qurilmalar")
    }

    func testUsbScopeHidesFieldRtdbLog() {
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
        let field = FieldDevice(id: "dev-xiaomi-1", label: "Xiaomi 2209116AG", count: 8)
        XCTAssertTrue(LogFilter.matchesDevice(log, scope: .field(field)))
        XCTAssertFalse(LogFilter.matchesDevice(log, scope: .field(FieldDevice(id: "o", label: "SOTEN T101_2021", count: 1))))
        XCTAssertTrue(LogFilter.apply([log], appId: "all", scope: .usb(usb), status: .all, query: "").isEmpty)
        XCTAssertTrue(LogFilter.apply([log], appId: "all", scope: .all, status: .all, query: "").isEmpty)
        XCTAssertEqual(FieldDevices.collect([log, log]).first?.count, 2)
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
        let out = LogFilter.apply([older, newer], appId: "all", device: nil, status: .all, query: "")
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
    }
}
