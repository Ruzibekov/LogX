import XCTest
@testable import LogXCore

final class InspectorCompleteTests: XCTestCase {
    private func live(
        _ key: String,
        method: String = "GET",
        url: String = "https://api.example.com/v1/persons",
        code: Int? = 200,
        duration: Int? = 120,
        ts: Double? = 10,
        serial: String = "A",
        source: String = "logcat",
        headers: [String: String] = [:],
        reqBody: String? = nil,
        resBody: String? = nil,
        resHeaders: [String: String] = [:]
    ) -> NetworkLog {
        NetworkLog(
            key: key,
            method: method,
            url: url,
            responseCode: code,
            durationMs: duration,
            source: source,
            serial: serial,
            ts: ts,
            requestHeaders: headers,
            responseHeaders: resHeaders,
            requestBody: reqBody,
            responseBody: resBody
        )
    }


    func testMatchesQuery_bodyHeaderParams_happyAndMiss() {
        let log = live(
            "q1",
            url: "https://api.example.com/v1/persons?pinfl=31234567890011&page=2",
            headers: ["X-Trace": "trace-abc", "Accept": "application/json"],
            reqBody: #"{"pinfl":"31234567890011","name":"Ali"}"#,
            resBody: #"{"token":"tok_live_zzz","ok":true}"#,
            resHeaders: ["X-Request-Id": "req-99"]
        )
        XCTAssertTrue(LogFilter.matchesQuery(log, query: "31234567890011"))
        XCTAssertTrue(LogFilter.matchesQuery(log, query: "tok_live_zzz"))
        XCTAssertTrue(LogFilter.matchesQuery(log, query: "X-Trace"))
        XCTAssertTrue(LogFilter.matchesQuery(log, query: "trace-abc"))
        XCTAssertTrue(LogFilter.matchesQuery(log, query: "req-99"))
        XCTAssertTrue(LogFilter.matchesQuery(log, query: "page"))
        XCTAssertTrue(LogFilter.matchesQuery(log, query: "PINFL"))
        XCTAssertFalse(LogFilter.matchesQuery(log, query: "missing-secret"))
        XCTAssertFalse(LogFilter.matchesQuery(log, query: "no-such-header"))
        XCTAssertTrue(LogFilter.matchesQuery(log, query: ""))
        XCTAssertTrue(LogFilter.matchesQuery(log, query: "   "))
    }

    func testMatchesQuery_emptyBodiesDoNotCrash() {
        let log = live("empty")
        XCTAssertFalse(LogFilter.matchesQuery(log, query: "nobody"))
        XCTAssertTrue(LogFilter.matchesQuery(log, query: "persons"))
    }


    func testNoise_analyticsHidden_personsKept() {
        let analytics = live("a", url: "https://www.google-analytics.com/g/collect")
        let crash = live("c", url: "https://crashlytics.googleapis.com/v1/log")
        let firebase = live("f", url: "https://firebaseinstallations.googleapis.com/v1/x")
        let fb = live("fb", url: "https://graph.facebook.com/v19.0/tr")
        let persons = live("p", url: "https://api.online-mahalla.uz/v1/persons")
        XCTAssertTrue(LogNoise.isNoise(analytics))
        XCTAssertTrue(LogNoise.isNoise(crash))
        XCTAssertTrue(LogNoise.isNoise(firebase))
        XCTAssertTrue(LogNoise.isNoise(fb))
        XCTAssertFalse(LogNoise.isNoise(persons))

        let hidden = LogFilter.apply(
            [analytics, crash, firebase, fb, persons],
            appId: "all", scope: .all, status: .all, query: "", hideNoise: true
        )
        XCTAssertEqual(hidden.map(\.key), ["p"])

        let kept = LogFilter.apply(
            [analytics, persons],
            appId: "all", scope: .all, status: .all, query: "", hideNoise: false
        )
        XCTAssertEqual(Set(kept.map(\.key)), ["a", "p"])
    }

    func testNoise_healthPingImagesAndDefaultApplyKeepsAnalytics() {
        XCTAssertTrue(LogNoise.isNoise(live("h", url: "https://api.example.com/health")))
        XCTAssertTrue(LogNoise.isNoise(live("r", url: "https://api.example.com/ready")))
        XCTAssertTrue(LogNoise.isNoise(live("l", url: "https://api.example.com/live")))
        XCTAssertTrue(LogNoise.isNoise(live("pi", url: "https://api.example.com/ping")))
        XCTAssertTrue(LogNoise.isNoise(live("m", url: "https://api.example.com/metrics")))
        XCTAssertTrue(LogNoise.isNoise(live("fv", url: "https://api.example.com/favicon.ico")))
        XCTAssertTrue(LogNoise.isNoise(live("png", url: "https://cdn.example.com/img/logo.png")))
        XCTAssertTrue(LogNoise.isNoise(live("jpg", url: "https://cdn.example.com/a.jpg?w=2")))
        XCTAssertTrue(LogNoise.isNoise(live("webp", url: "https://cdn.example.com/x.webp")))
        XCTAssertFalse(LogNoise.isNoise(live("p", url: "https://api.example.com/v1/persons")))
        XCTAssertFalse(LogNoise.isNoise(live("adj", url: "https://api.example.com/v1/adjustment")))

        let analytics = live("ga", url: "https://www.google-analytics.com/collect")
        let out = LogFilter.apply([analytics], appId: "all", scope: .all, status: .all, query: "")
        XCTAssertEqual(out.map(\.key), ["ga"], "apply hideNoise default false — eski testlar analytics ko‘radi")
    }

    func testNoise_emptyAndAppsflyerSentryAmplitudeAdjust() {
        XCTAssertFalse(LogNoise.isNoise(live("e", url: "")))
        XCTAssertTrue(LogNoise.isNoise(live("af", url: "https://t.appsflyer.com/api")))
        XCTAssertTrue(LogNoise.isNoise(live("s", url: "https://o123.ingest.sentry.io/api/x")))
        XCTAssertTrue(LogNoise.isNoise(live("am", url: "https://api2.amplitude.com/2/httpapi")))
        XCTAssertTrue(LogNoise.isNoise(live("ad", url: "https://app.adjust.com/event")))
        XCTAssertTrue(LogNoise.isNoise(live("dc", url: "https://ad.doubleclick.net/x")))
    }


    func testApply_slowHostMethod_andEmpty() {
        let fast = live("fast", duration: 100, ts: 1)
        let slow = live("slow", duration: 900, ts: 2)
        let nilDur = live("nil", duration: nil, ts: 3)
        let otherHost = live("h2", url: "https://other.uz/v1/x", duration: 900, ts: 4)
        let post = live("post", method: "POST", duration: 900, ts: 5)

        XCTAssertEqual(
            LogFilter.apply([fast, slow, nilDur], appId: "all", scope: .all, status: .all, query: "", slowOnly: true).map(\.key),
            ["slow"]
        )
        XCTAssertTrue(
            LogFilter.apply([fast, nilDur], appId: "all", scope: .all, status: .all, query: "", slowOnly: true).isEmpty
        )
        XCTAssertEqual(
            LogFilter.apply([fast, otherHost], appId: "all", scope: .all, status: .all, query: "", selectedHost: "other.uz").map(\.key),
            ["h2"]
        )
        XCTAssertEqual(
            LogFilter.apply([fast, otherHost], appId: "all", scope: .all, status: .all, query: "", selectedHost: "").count,
            2
        )
        XCTAssertTrue(
            LogFilter.apply([fast], appId: "all", scope: .all, status: .all, query: "", selectedHost: "missing.host").isEmpty
        )
        XCTAssertEqual(
            LogFilter.apply([fast, post], appId: "all", scope: .all, status: .all, query: "", method: "POST").map(\.key),
            ["post"]
        )
        XCTAssertEqual(
            LogFilter.apply([fast, post], appId: "all", scope: .all, status: .all, query: "", method: "ALL").count,
            2
        )
        XCTAssertTrue(LogFilter.apply([], appId: "all", scope: .all, status: .all, query: "", method: "GET", slowOnly: true).isEmpty)
        XCTAssertEqual(LogNoise.slowThresholdMs, 800)
        XCTAssertTrue(LogFilter.matchesSlow(slow, slowOnly: true))
        XCTAssertFalse(LogFilter.matchesSlow(fast, slowOnly: true))
        XCTAssertTrue(LogFilter.matchesSlow(fast, slowOnly: false))
    }

    func testStatusCountsHonorMethodNoiseSlowHost() {
        let getOk = live("g", method: "GET", url: "https://api.example.com/v1/persons", code: 200, duration: 100)
        let postErr = live("p", method: "POST", url: "https://api.example.com/v1/persons", code: 500, duration: 900)
        let noise = live("n", method: "GET", url: "https://www.google-analytics.com/g", code: 200, duration: 50)
        let countsGet = LogFilter.statusCounts(
            [getOk, postErr, noise],
            appId: "all", scope: .all, query: "", method: "GET", hideNoise: true
        )
        XCTAssertEqual(countsGet[.all], 1)
        XCTAssertEqual(countsGet[.ok2xx], 1)
        XCTAssertEqual(countsGet[.err5xx], 0)

        let countsSlow = LogFilter.statusCounts(
            [getOk, postErr],
            appId: "all", scope: .all, query: "", slowOnly: true
        )
        XCTAssertEqual(countsSlow[.all], 1)
        XCTAssertEqual(countsSlow[.err5xx], 1)

        let empty = LogFilter.statusCounts([], appId: "all", scope: .all, query: "")
        XCTAssertEqual(empty[.all], 0)
        XCTAssertEqual(empty[.ok2xx], 0)
    }


    func testHAR_structureAndRedact() throws {
        let log = live(
            "e1",
            method: "POST",
            url: "https://api.example.com/v1/login?x=1",
            code: 200,
            duration: 42,
            headers: ["Authorization": "Bearer super-secret-token", "Accept": "application/json"],
            reqBody: #"{"token":"raw-secret-value","name":"Ali"}"#,
            resBody: #"{"access_token":"also-secret"}"#
        )
        let data = SessionExport.har(logs: [log], redact: true)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let harLog = try XCTUnwrap(obj?["log"] as? [String: Any])
        XCTAssertEqual(harLog["version"] as? String, "1.2")
        let creator = try XCTUnwrap(harLog["creator"] as? [String: Any])
        XCTAssertEqual(creator["name"] as? String, "LogX")
        let entries = try XCTUnwrap(harLog["entries"] as? [[String: Any]])
        XCTAssertEqual(entries.count, 1)
        let req = try XCTUnwrap(entries[0]["request"] as? [String: Any])
        let res = try XCTUnwrap(entries[0]["response"] as? [String: Any])
        XCTAssertNotNil(req["method"])
        XCTAssertNotNil(res["status"])
        let raw = String(data: data, encoding: .utf8) ?? ""
        XCTAssertFalse(raw.contains("super-secret-token"), raw)
        XCTAssertFalse(raw.contains("raw-secret-value"), raw)
        XCTAssertFalse(raw.contains("also-secret"), raw)
        XCTAssertTrue(raw.contains("••••••"), raw)
        let post = try XCTUnwrap(req["postData"] as? [String: Any])
        XCTAssertEqual(post["mimeType"] as? String, "application/json")
        let headers = try XCTUnwrap(req["headers"] as? [[String: String]])
        XCTAssertEqual(headers.first(where: { $0["name"] == "Authorization" })?["value"], "••••••")
    }

    func testHAR_emptyAndSingleLog() throws {
        let empty = SessionExport.har(logs: [], redact: false)
        let obj = try JSONSerialization.jsonObject(with: empty) as? [String: Any]
        let harLog = try XCTUnwrap(obj?["log"] as? [String: Any])
        XCTAssertEqual(harLog["version"] as? String, "1.2")
        XCTAssertEqual((harLog["entries"] as? [Any])?.count, 0)

        let one = live("only")
        let data = SessionExport.har(logs: [one], redact: false)
        let oneObj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let entries = try XCTUnwrap((oneObj?["log"] as? [String: Any])?["entries"] as? [Any])
        XCTAssertEqual(entries.count, 1)
    }

    func testJSONExport_redactAndEmpty() throws {
        let log = live(
            "j1",
            headers: ["Authorization": "Bearer leak-me"],
            reqBody: #"{"refresh_token":"leak-body"}"#
        )
        let data = SessionExport.json(logs: [log], redact: true)
        let raw = String(data: data, encoding: .utf8) ?? ""
        XCTAssertFalse(raw.contains("leak-me"), raw)
        XCTAssertFalse(raw.contains("leak-body"), raw)
        XCTAssertTrue(raw.contains("••••••"), raw)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(obj?["redacted"] as? Bool, true)
        XCTAssertEqual(obj?["count"] as? Int, 1)

        let empty = try JSONSerialization.jsonObject(with: SessionExport.json(logs: [], redact: false)) as? [String: Any]
        XCTAssertEqual(empty?["count"] as? Int, 0)
        XCTAssertEqual((empty?["items"] as? [Any])?.count, 0)
    }

    func testJSONExport_withoutRedactKeepsSecret() throws {
        let log = live("j2", headers: ["Authorization": "Bearer visible-token"])
        let raw = String(data: SessionExport.json(logs: [log], redact: false), encoding: .utf8) ?? ""
        XCTAssertTrue(raw.contains("visible-token"), raw)
    }


    func testJSONFind_nextPrevWrapEmpty() {
        XCTAssertEqual(JSONFind.matches("{}", query: ""), [])
        XCTAssertEqual(JSONFind.matches("", query: "a"), [])
        XCTAssertEqual(JSONFind.matches("  ", query: "   "), [])
        let text = #"{"Name":"Ali","name":"Vali","token":"x"}"#
        let hits = JSONFind.matches(text, query: "name")
        XCTAssertEqual(hits.count, 2)
        XCTAssertEqual(JSONFind.matches(text, query: "NAME").count, 2)
        XCTAssertEqual(JSONFind.matches(text, query: "nope").count, 0)

        XCTAssertEqual(JSONFind.nextIndex(current: 0, count: 0), 0)
        XCTAssertEqual(JSONFind.nextIndex(current: 0, count: 3), 1)
        XCTAssertEqual(JSONFind.nextIndex(current: 2, count: 3), 0)
        XCTAssertEqual(JSONFind.nextIndex(current: 0, count: 3, reverse: true), 2)
        XCTAssertEqual(JSONFind.nextIndex(current: 1, count: 3, reverse: true), 0)
        let wrap = JSONFind.nextIndex(current: JSONFind.nextIndex(current: 2, count: 3), count: 3)
        XCTAssertEqual(wrap, 1)
        XCTAssertEqual(JSONFind.nextIndex(current: -1, count: 3), 0)
        XCTAssertEqual(JSONFind.nextIndex(current: 99, count: 3), 1)
    }


    func testEndpointCounts_methodHostPathIgnoresQuery() {
        let a = live("a", method: "GET", url: "https://api.example.com/v1/persons?page=1")
        let b = live("b", method: "GET", url: "https://api.example.com/v1/persons?page=2")
        let c = live("c", method: "POST", url: "https://api.example.com/v1/persons")
        let d = live("d", method: "GET", url: "https://other.uz/v1/persons")
        let counts = EndpointIdentity.counts(in: [a, b, c, d])
        XCTAssertEqual(counts[EndpointIdentity.key(for: a)], 2)
        XCTAssertEqual(EndpointIdentity.key(for: a), EndpointIdentity.key(for: b))
        XCTAssertNotEqual(EndpointIdentity.key(for: a), EndpointIdentity.key(for: c))
        XCTAssertNotEqual(EndpointIdentity.key(for: a), EndpointIdentity.key(for: d))
        XCTAssertTrue(EndpointIdentity.key(for: a).hasPrefix("GET "))
        XCTAssertFalse(EndpointIdentity.key(for: a).contains("page="))
        XCTAssertEqual(a.pathOnly, "/v1/persons")
        XCTAssertEqual(EndpointIdentity.uniqueHosts([a, b, d]), ["api.example.com", "other.uz"])
        XCTAssertEqual(EndpointIdentity.counts(in: []).isEmpty, true)
        XCTAssertEqual(EndpointIdentity.uniqueHosts([]), [])
        XCTAssertEqual(NetworkLog(key: "p", url: "/only/path?x=1").pathOnly, "/only/path")
    }


    func testPrefs_roundtripAndDefaults() throws {
        let suiteName = "logx.tests.inspector.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let missing = InspectorPrefs.load(defaults: defaults)
        XCTAssertEqual(missing, .default)
        XCTAssertTrue(missing.hideNoise)
        XCTAssertFalse(missing.followLatest)
        XCTAssertFalse(missing.slowOnly)
        XCTAssertEqual(missing.selectedMethod, "ALL")
        XCTAssertEqual(missing.status, StatusClass.all.rawValue)
        XCTAssertFalse(missing.errorsOnly)
        XCTAssertEqual(missing.selectedAppId, "all")
        XCTAssertNil(missing.selectedSerial)

        let prefs = InspectorPrefs(
            hideNoise: false,
            followLatest: true,
            slowOnly: true,
            selectedMethod: "POST",
            status: StatusClass.err4xx.rawValue,
            errorsOnly: true,
            selectedAppId: "mahalla",
            selectedSerial: "USB-1"
        )
        prefs.save(defaults: defaults)
        let loaded = InspectorPrefs.load(defaults: defaults)
        XCTAssertEqual(loaded, prefs)

        let again = InspectorPrefs.load(defaults: defaults)
        XCTAssertEqual(again, loaded)

        defaults.set(Data("{}".utf8), forKey: InspectorPrefs.storageKey)
        let partial = InspectorPrefs.load(defaults: defaults)
        XCTAssertTrue(partial.hideNoise)
        XCTAssertFalse(partial.followLatest)

        defaults.set(Data("not-json".utf8), forKey: InspectorPrefs.storageKey)
        XCTAssertEqual(InspectorPrefs.load(defaults: defaults), .default)

        let encoded = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(InspectorPrefs.self, from: encoded)
        XCTAssertEqual(decoded.selectedSerial, "USB-1")
        defaults.removePersistentDomain(forName: suiteName)
    }


    func testFollowLatest_ingestPausedEmptyAndNewest() {
        let old = live("old", ts: 1)
        let new = live("new", ts: 9)
        let rtdb = NetworkLog(key: "rtdb", source: "rtdb", ts: 99)

        XCTAssertEqual(
            FollowLatest.selectedKey(batch: [old, new], currentKey: "old", follow: true, paused: false),
            "new"
        )
        XCTAssertEqual(
            FollowLatest.selectedKey(batch: [new, old], currentKey: "old", follow: true, paused: false),
            "new"
        )
        XCTAssertEqual(
            FollowLatest.selectedKey(batch: [old, new], currentKey: "old", follow: true, paused: true),
            "old"
        )
        XCTAssertEqual(
            FollowLatest.selectedKey(batch: [rtdb], currentKey: "old", follow: true, paused: false),
            "old"
        )
        XCTAssertEqual(
            FollowLatest.selectedKey(batch: [], currentKey: "keep", follow: true, paused: false),
            "keep"
        )
        XCTAssertEqual(
            FollowLatest.selectedKey(batch: [old, new], currentKey: nil, follow: false, paused: false),
            "old"
        )
        XCTAssertEqual(
            FollowLatest.selectedKey(batch: [old, new], currentKey: "old", follow: false, paused: false),
            "old"
        )
        let second = FollowLatest.selectedKey(
            batch: [live("later", ts: 50)],
            currentKey: FollowLatest.selectedKey(batch: [old, new], currentKey: nil, follow: true, paused: false),
            follow: true,
            paused: false
        )
        XCTAssertEqual(second, "later")
    }

    func testPathOnly_stripsQueryAndHost() {
        XCTAssertEqual(live("u", url: "https://api.example.com/v1/x?a=1").pathOnly, "/v1/x")
        XCTAssertEqual(live("u2", url: "https://api.example.com/v1/x").hostLabel, "api.example.com")
        XCTAssertEqual(NetworkLog(key: "n").pathOnly, "")
    }


    private func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    func testStoreFollowSelectLogAndExportSource() throws {
        let store = try source("Sources/LogX/Store.swift")
        let live = try source("Sources/LogX/Store+Live.swift")
        let inspector = try source("Sources/LogX/Store+Inspector.swift")
        XCTAssertTrue(store.contains("followLatest = false"), store)
        XCTAssertTrue(store.contains("hideNoise = true"), store)
        XCTAssertTrue(store.contains("slowOnly"), store)
        XCTAssertTrue(store.contains("selectedHost"), store)
        XCTAssertTrue(store.contains("InspectorPrefs.load"), store)
        XCTAssertTrue(live.contains("FollowLatest.selectedKey"), live)
        XCTAssertTrue(live.contains("followLatest"), live)
        XCTAssertTrue(inspector.contains("logx-session.har"), inspector)
        XCTAssertTrue(inspector.contains("logx-session.json"), inspector)
        XCTAssertTrue(inspector.contains("NSSavePanel"), inspector)
        XCTAssertTrue(inspector.contains("visibleLogs"), inspector)
        XCTAssertFalse(store.contains("/api/network-logs"), store)
        XCTAssertTrue(store.contains("slowOnly"), store)
        XCTAssertTrue(store.contains("selectedHost"), store)
    }

    func testUICopyAndFindSource() throws {
        let list = try source("Sources/LogX/Views/RequestList.swift")
        let detail = try source("Sources/LogX/Views/RequestDetail.swift")
        let find = try source("Sources/LogX/Views/DetailFindBar.swift")
        let app = try source("Sources/LogX/LogXApp.swift")
        let content = try source("Sources/LogX/Views/ContentView.swift")
        let row = try source("Sources/LogX/Views/RequestRow.swift")
        let hl = try source("Sources/LogX/Views/JSONHighlighter.swift")
        XCTAssertTrue(list.contains("Shovqin"), list)
        XCTAssertTrue(list.contains("Sekin"), list)
        XCTAssertTrue(list.contains("HAR nusxalash"), list)
        XCTAssertTrue(list.contains("Yo'lni nusxalash"), list)
        XCTAssertTrue(find.contains("Topish"), find)
        XCTAssertTrue(find.contains("keyboardShortcut(\"g\""), find)
        XCTAssertTrue(detail.contains("DetailFindBar"), detail)
        XCTAssertTrue(detail.contains("activeIndex"), detail)
        XCTAssertTrue(app.contains("Kuzat"), app)
        XCTAssertTrue(app.contains("Shovqinni yashirish"), app)
        XCTAssertTrue(app.contains("HAR saqlash"), app)
        XCTAssertTrue(app.contains("JSON saqlash"), app)
        XCTAssertTrue(content.contains("arrow.down.to.line"), content)
        XCTAssertTrue(content.contains("square.and.arrow.down"), content)
        XCTAssertTrue(content.contains("Saqlash"), content)
        XCTAssertTrue(row.contains("×"), row)
        XCTAssertTrue(hl.contains("120_000"), hl)
        XCTAssertTrue(hl.contains("highlights"), hl)
        let rail = try source("Sources/LogX/Views/DeviceRail.swift")
        XCTAssertFalse(rail.contains("selectField"), rail)
        XCTAssertFalse(rail.contains("TARMOQ"), rail)
        let monitor = try source("Sources/LogXCore/MonitorClient.swift")
        XCTAssertFalse(monitor.contains("/api/network-logs"), monitor)
    }

    func testClearFiltersDoesNotResetNoiseFollow() throws {
        let store = try source("Sources/LogX/Store.swift")
        XCTAssertTrue(store.contains("slowOnly = false"), store)
        XCTAssertTrue(store.contains("selectedHost = nil"), store)
        let clear = store.components(separatedBy: "func clearFilters()").dropFirst().first ?? ""
        let body = String(clear.prefix(500))
        XCTAssertFalse(body.contains("hideNoise = false"), body)
        XCTAssertFalse(body.contains("followLatest = false"), body)
        XCTAssertFalse(body.contains("redactEnabled = false"), body)
    }
}
