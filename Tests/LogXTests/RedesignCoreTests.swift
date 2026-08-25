import XCTest
@testable import LogXCore

final class RedesignCoreTests: XCTestCase {
    func testClockFormatsHMSInUTC() {
        let utc = TimeZone(secondsFromGMT: 0)!
        XCTAssertEqual(RelativeTime.clock(ts: nil, timeZone: utc), "—")
        XCTAssertEqual(RelativeTime.clock(ts: 1_000, timeZone: utc), "00:16:40")
        XCTAssertEqual(RelativeTime.clock(ts: 1_000_000, timeZone: utc), "13:46:40")
        XCTAssertEqual(RelativeTime.clock(ts: 1_000_000_000_000, timeZone: utc), "01:46:40")
    }

    func testRelativeTimeLabels() {
        let now = Date(timeIntervalSince1970: 10_000)
        XCTAssertEqual(RelativeTime.label(ts: nil, now: now), "—")
        XCTAssertEqual(RelativeTime.label(ts: 9_998, now: now), "endi")
        XCTAssertEqual(RelativeTime.label(ts: 9_950, now: now), "50s")
        XCTAssertEqual(RelativeTime.label(ts: 9_940, now: now), "1daq")
        XCTAssertEqual(RelativeTime.label(ts: 9_000, now: now), "16daq")
        XCTAssertEqual(RelativeTime.label(ts: 6_000, now: now), "1soat")
        XCTAssertEqual(RelativeTime.label(ts: 10_000 - 172_800, now: now), "2kun")
        // ms epoxa ham qo'llanadi
        XCTAssertEqual(RelativeTime.label(ts: 9_998_000, now: now), "endi")
        XCTAssertTrue(RelativeTime.isFresh(ts: 9_996, now: now))
        XCTAssertFalse(RelativeTime.isFresh(ts: 9_000, now: now))
    }

    func testCurlBuilder() {
        let log = NetworkLog(
            key: "c1",
            method: "POST",
            url: "https://api.example.uz/v1/x?a=1",
            requestHeaders: ["Authorization": "Bearer tok", "Accept": "application/json"],
            requestBody: #"{"a":1}"#
        )
        let cmd = CurlBuilder.command(for: log)
        XCTAssertTrue(cmd.hasPrefix("curl -X POST 'https://api.example.uz/v1/x?a=1' \\\n  -H 'Accept: application/json'"), cmd)
        XCTAssertTrue(cmd.contains("-H 'Accept: application/json'"), cmd)
        XCTAssertTrue(cmd.contains("--data-binary '{\"a\":1}'"), cmd)
        // GET'da -X yo'q; kalitlar alifboda
        let get = NetworkLog(key: "c2", method: "GET", url: "https://x.uz/a")
        XCTAssertFalse(CurlBuilder.command(for: get).contains("-X"))
        // Bo'sh URL — bo'sh buyruq
        XCTAssertTrue(CurlBuilder.command(for: NetworkLog(key: "c3")).isEmpty)
        // Qavs maneuveri
        XCTAssertEqual(CurlBuilder.squote("a'b"), "'a'\\''b'")
    }

    func testCurlBuilderRedact() {
        let log = NetworkLog(
            key: "c4",
            method: "GET",
            url: "https://x.uz/sec",
            requestHeaders: ["Authorization": "Bearer secret", "X-Track": "abc"]
        )
        let cmd = CurlBuilder.command(for: log, redact: true)
        XCTAssertFalse(cmd.contains("secret"), cmd)
        XCTAssertTrue(cmd.contains("••••••"), cmd)
        XCTAssertTrue(cmd.contains("X-Track: abc"), cmd)
    }

    func testRedactorMasksSensitiveKeys() {
        let masked = Redactor.mask([
            "Authorization": "Bearer xyz", "Cookie": "a=b",
            "device-id": "bc72", "Accept": "application/json",
        ])
        XCTAssertEqual(masked["Authorization"], "••••••")
        XCTAssertEqual(masked["Cookie"], "••••••")
        XCTAssertEqual(masked["device-id"], "bc72")
        XCTAssertEqual(masked["Accept"], "application/json")
        XCTAssertTrue(Redactor.isSensitive("X-Auth-Token"))
        XCTAssertFalse(Redactor.isSensitive("Accept"))
        let body = Redactor.maskText("Bearer abcdef123 rest")
        XCTAssertEqual(body, "Bearer •••••• rest")
    }

    func testRedirect3xxIsOwnClass() {
        XCTAssertEqual(NetworkLog(key: "r", responseCode: 302).statusClass, .redirect3xx)
        XCTAssertEqual(NetworkLog(key: "r", responseCode: 301).statusClass, .redirect3xx)
        XCTAssertEqual(StatusClass.redirect3xx.title, "3xx")
        XCTAssertEqual(LogXThemeStatus.redirect3xxColorHint, "#64A9E0")
    }

    func testErrorsOnlyFilter() {
        let logs = [
            NetworkLog(key: "ok", responseCode: 200, source: "logcat", serial: "A"),
            NetworkLog(key: "r3", responseCode: 302, source: "logcat", serial: "A"),
            NetworkLog(key: "e4", responseCode: 401, source: "logcat", serial: "A"),
            NetworkLog(key: "e5", responseCode: 500, source: "logcat", serial: "A"),
            NetworkLog(key: "net", source: "logcat", serial: "A"),
        ]
        let out = LogFilter.apply(logs, appId: "all", scope: .all, status: .all, query: "", errorsOnly: true)
        XCTAssertEqual(out.map(\.key).sorted(), ["e4", "e5", "net"])
        XCTAssertEqual(LogFilter.errorClasses, [.err4xx, .err5xx, .net])
        let normal = LogFilter.apply(logs, appId: "all", scope: .all, status: .all, query: "")
        XCTAssertEqual(normal.count, 5)
    }

    func testQueryParamsAndStatusDescription() {
        let log = NetworkLog(
            key: "q1",
            method: "GET",
            url: "https://api.online-mahalla.uz/v1/persons?page=2&limit=50&status=active",
            responseCode: 200,
            durationMs: 450,
            responseBody: #"{"items":[]}"#
        )
        XCTAssertEqual(log.queryParams.count, 3)
        XCTAssertEqual(log.queryParams[0].key, "page")
        XCTAssertEqual(log.queryParams[0].value, "2")
        XCTAssertEqual(log.queryParams[1].key, "limit")
        XCTAssertEqual(log.queryParams[1].value, "50")
        XCTAssertEqual(log.queryParams[2].key, "status")
        XCTAssertEqual(log.queryParams[2].value, "active")
        XCTAssertEqual(log.statusDescription, "OK")
        XCTAssertEqual(log.formattedDuration, "450 ms")
        XCTAssertEqual(NetworkLog(key: "d2", durationMs: 1500).formattedDuration, "1.50 s")
        XCTAssertEqual(NetworkLog(key: "s404", responseCode: 404).statusDescription, "Not Found")
        XCTAssertEqual(NetworkLog(key: "s500", responseCode: 500).statusDescription, "Internal Server Error")
        XCTAssertEqual(NetworkLog(key: "s502", responseCode: 502).statusDescription, "Bad Gateway")

        let paramsBody = JSONFormat.body(for: log, tab: .params)
        XCTAssertTrue(paramsBody.contains("page: 2"))
        XCTAssertTrue(paramsBody.contains("limit: 50"))
    }
}

// Theme ranglari LogX (app target)da — core testda faqat hint qoladi.
public enum LogXThemeStatus {
    public static let redirect3xxColorHint = "#64A9E0"
}
