import XCTest
@testable import LogX
@testable import LogXCore

final class JSONTreeTests: XCTestCase {
    private let sample = """
    {"data":{"items":[{"id":1,"name":"a b","ok":true},{"id":2,"name":null,"tags":[]}],"total":2},"meta":{"page":1,"size":2.5,"deep":{"x":{"y":1}}}}
    """

    func testBuildsSortedNodesWithPaths() throws {
        let tree = try XCTUnwrap(JSONTree(text: sample, identity: "t"))
        XCTAssertEqual(tree.nodes.first?.id, "$")
        XCTAssertEqual(tree.nodes.first?.kind, .object)
        let ids = tree.nodes.map(\.id)
        XCTAssertTrue(ids.contains("$.data.items[0].id"))
        XCTAssertTrue(ids.contains("$.data.items[1].tags"))
        XCTAssertTrue(ids.contains("$.meta.deep.x.y"))
        let keysUnderRoot = tree.nodes.filter { $0.depth == 1 }.map(\.key)
        XCTAssertEqual(keysUnderRoot, ["data", "meta"])
    }

    func testScalarsAndKinds() throws {
        let tree = try XCTUnwrap(JSONTree(text: sample, identity: "t"))
        XCTAssertEqual(tree.node(id: "$.data.items[0].name")?.scalar, "\"a b\"")
        XCTAssertEqual(tree.node(id: "$.data.items[0].ok")?.kind, .bool)
        XCTAssertEqual(tree.node(id: "$.data.items[0].ok")?.scalar, "true")
        XCTAssertEqual(tree.node(id: "$.data.items[1].name")?.kind, .null)
        XCTAssertEqual(tree.node(id: "$.meta.size")?.scalar, "2.5")
        XCTAssertEqual(tree.node(id: "$.data.items[0].id")?.scalar, "1")
        XCTAssertEqual(tree.node(id: "$.data.items[1].tags")?.childCount, 0)
    }

    func testCollapseSkipsSubtree() throws {
        let tree = try XCTUnwrap(JSONTree(text: sample, identity: "t"))
        let all = tree.rows(collapsed: [])
        XCTAssertEqual(all.count, tree.count)
        let rows = tree.rows(collapsed: ["$.data"])
        XCTAssertTrue(rows.contains { $0.id == "$.data" })
        XCTAssertFalse(rows.contains { $0.id == "$.data.items" })
        XCTAssertTrue(rows.contains { $0.id == "$.meta.page" })
        let defaults = tree.defaultCollapsed()
        XCTAssertTrue(defaults.contains("$.data.items"))
        XCTAssertFalse(defaults.contains("$.data"))
        XCTAssertFalse(defaults.contains("$.data.items[1].tags"), "bo'sh konteyner yig'ilmaydi")
    }

    func testSubtreeAndAncestors() throws {
        let tree = try XCTUnwrap(JSONTree(text: sample, identity: "t"))
        XCTAssertEqual(tree.subtreeContainerIDs(of: "$.meta"), ["$.meta", "$.meta.deep", "$.meta.deep.x"])
        XCTAssertEqual(tree.ancestorIDs(of: "$.meta.deep.x.y"), ["$", "$.meta", "$.meta.deep", "$.meta.deep.x"])
    }

    func testMatchesAndValueText() throws {
        let tree = try XCTUnwrap(JSONTree(text: sample, identity: "t"))
        XCTAssertEqual(tree.matches(query: "name"), ["$.data.items[0].name", "$.data.items[1].name"])
        XCTAssertEqual(tree.matches(query: "A B"), ["$.data.items[0].name"])
        XCTAssertEqual(tree.matches(query: "  "), [])
        XCTAssertEqual(tree.valueText(id: "$.data.items[0].name"), "a b")
        XCTAssertEqual(tree.valueText(id: "$.meta.page"), "1")
        let sub = try XCTUnwrap(tree.valueText(id: "$.meta.deep"))
        XCTAssertTrue(sub.contains("\"x\""))
        XCTAssertTrue(sub.contains("\"y\" : 1") || sub.contains("\"y\": 1"))
    }

    func testNonJSONAndLimit() {
        XCTAssertNil(JSONTree(text: "plain text", identity: "t"))
        XCTAssertNil(JSONTree(text: "\"just a string\"", identity: "t"))
        XCTAssertNil(JSONTree(text: "", identity: "t"))
        let huge = "[" + Array(repeating: "1", count: JSONTree.nodeLimit + 10).joined(separator: ",") + "]"
        XCTAssertNil(JSONTree(text: huge, identity: "t"), "limitdan katta tana daraxt bo'lmaydi — matn rejimi qoladi")
    }

    func testPathQuotesNonIdentifierKeys() {
        XCTAssertEqual(JSONTree.path([.key("a-b"), .index(3), .key("ok_1")]), "$[\"a-b\"][3].ok_1")
    }
}

final class TextDiffTests: XCTestCase {
    func testIdentical() {
        let d = TextDiff.lines(old: "a\nb", new: "a\nb")
        XCTAssertTrue(d.identical)
        XCTAssertEqual(d.lines.map(\.op), [.same, .same])
        XCTAssertEqual(d.compact(), [])
    }

    func testInsertDeleteWithLineNumbers() {
        let d = TextDiff.lines(old: "a\nb\nc\nd", new: "a\nx\nc\nd\ne")
        XCTAssertEqual(d.inserted, 2)
        XCTAssertEqual(d.deleted, 1)
        XCTAssertEqual(d.lines.map(\.op), [.same, .delete, .insert, .same, .same, .insert])
        XCTAssertEqual(d.lines[1].oldLine, 2)
        XCTAssertEqual(d.lines[2].newLine, 2)
        XCTAssertEqual(d.lines[5].newLine, 5)
        XCTAssertNil(d.lines[5].oldLine)
    }

    func testEmptySides() {
        XCTAssertEqual(TextDiff.lines(old: "", new: "a\nb").inserted, 2)
        XCTAssertEqual(TextDiff.lines(old: "a", new: "").deleted, 1)
        XCTAssertTrue(TextDiff.lines(old: "", new: "").identical)
    }

    func testCompactCollapsesGaps() {
        let old = (1...20).map(String.init).joined(separator: "\n")
        let new = (1...20).map { $0 == 10 ? "X" : String($0) }.joined(separator: "\n")
        let lines = TextDiff.lines(old: old, new: new).compact(context: 2)
        XCTAssertEqual(lines.first?.op, .gap)
        XCTAssertEqual(lines.first?.text, "⋯ 7 qator bir xil")
        XCTAssertEqual(lines.last?.op, .gap)
        XCTAssertEqual(lines.last?.text, "⋯ 8 qator bir xil")
        XCTAssertEqual(lines.filter { $0.op == .same }.count, 4)
        XCTAssertTrue(TextDiff.unified(lines).contains("- 10\n+ X"))
    }

    func testHugeMiddleFallsBackToBlocks() {
        let old = (1...3000).map { "o\($0)" }.joined(separator: "\n")
        let new = (1...3000).map { "n\($0)" }.joined(separator: "\n")
        let d = TextDiff.lines(old: old, new: new)
        XCTAssertTrue(d.truncated)
        XCTAssertEqual(d.deleted, 3000)
        XCTAssertEqual(d.inserted, 3000)
    }

    func testPrefixSuffixTrimKeepsAlignment() {
        let old = "{\n  \"a\": 1,\n  \"b\": 2\n}"
        let new = "{\n  \"a\": 1,\n  \"b\": 3\n}"
        let d = TextDiff.lines(old: old, new: new)
        XCTAssertEqual(d.lines.map(\.op), [.same, .same, .delete, .insert, .same])
        XCTAssertEqual(d.lines[4].oldLine, 4)
        XCTAssertEqual(d.lines[4].newLine, 4)
    }

    func testLogDiffSectionsAndPrevious() {
        let a = NetworkLog(key: "a", method: "GET", url: "https://h.uz/x?p=1", api: "", responseCode: 200, serial: "s", ts: 1, responseBody: "{\"v\":1}")
        let b = NetworkLog(key: "b", method: "GET", url: "https://h.uz/x?p=2", api: "", responseCode: 200, serial: "s", ts: 2, responseBody: "{\"v\":2}")
        let c = NetworkLog(key: "c", method: "POST", url: "https://h.uz/x", api: "", responseCode: 200, serial: "s", ts: 3)
        let d = LogDiff.diff(a, b, section: .response, redact: false)
        XCTAssertEqual(d.inserted, 1)
        XCTAssertEqual(d.deleted, 1)
        XCTAssertTrue(LogDiff.text(for: a, section: .url, redact: false).contains("p = 1"))
        let logs = [c, b, a]
        XCTAssertEqual(LogDiff.previousSameEndpoint(of: b, in: logs)?.key, "a")
        XCTAssertNil(LogDiff.previousSameEndpoint(of: a, in: logs))
        XCTAssertNil(LogDiff.previousSameEndpoint(of: c, in: logs), "metod farq qilsa bir endpoint emas")
    }
}

final class ReplayTests: XCTestCase {
    private func log(method: String = "POST", url: String = "https://api.example.uz/v1/items?x=1", body: String? = "{\"a\":1}") -> NetworkLog {
        NetworkLog(
            key: "k1", method: method, url: url, api: "", responseCode: 201, serial: "S1", ts: 1,
            requestHeaders: ["Authorization": "Bearer t", "Content-Length": "7", "Host": "x", "Accept-Encoding": "gzip", "X-Empty": ""],
            requestBody: body
        )
    }

    func testRequestBuild() throws {
        let req = try Replay.request(for: log())
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.url?.absoluteString, "https://api.example.uz/v1/items?x=1")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer t")
        XCTAssertNil(req.value(forHTTPHeaderField: "Host"))
        XCTAssertNil(req.value(forHTTPHeaderField: "Accept-Encoding"))
        XCTAssertNil(req.value(forHTTPHeaderField: "X-Empty"))
        XCTAssertEqual(req.httpBody, "{\"a\":1}".data(using: .utf8))
        XCTAssertEqual(req.timeoutInterval, Replay.timeout)
        XCTAssertEqual(req.cachePolicy, .reloadIgnoringLocalAndRemoteCacheData)
    }

    func testRequestBuildErrors() {
        XCTAssertThrowsError(try Replay.request(for: log(url: ""))) { XCTAssertEqual($0 as? Replay.BuildError, .emptyURL) }
        XCTAssertThrowsError(try Replay.request(for: log(url: "/relative/only")))
        XCTAssertThrowsError(try Replay.request(for: log(body: "(binary 812-byte body omitted)"))) {
            XCTAssertEqual($0 as? Replay.BuildError, .omittedBody)
        }
        XCTAssertEqual(try Replay.request(for: log(method: "?")).httpMethod, "GET")
        XCTAssertFalse(Replay.describe(Replay.BuildError.omittedBody).isEmpty)
    }

    func testMutatingAndReplayTag() {
        XCTAssertTrue(Replay.isMutating("post"))
        XCTAssertTrue(Replay.isMutating("DELETE"))
        XCTAssertFalse(Replay.isMutating("GET"))
        XCTAssertFalse(Replay.isMutating("PUT"))
        let replayed = Replay.log(from: ReplayResult(statusCode: 200, statusMessage: "OK", headers: ["Content-Type": "json"], body: "{}", durationMs: 42), original: log(), key: Replay.keyPrefix + "u", ts: 5)
        XCTAssertTrue(Replay.isReplay(replayed))
        XCTAssertFalse(Replay.isReplay(log()))
        XCTAssertEqual(replayed.responseCode, 200)
        XCTAssertEqual(replayed.durationMs, 42)
        XCTAssertEqual(replayed.serial, "S1")
        XCTAssertEqual(replayed.source, "replay")
        XCTAssertEqual(replayed.responseBody, "{}")
        XCTAssertEqual(replayed.requestBody, "{\"a\":1}")
        XCTAssertNil(replayed.requestHeaders["Host"])
        XCTAssertEqual(replayed.requestHeaders["Authorization"], "Bearer t")
        XCTAssertTrue(replayed.isFull)
        XCTAssertTrue(LogFilter.isLocal(replayed), "replay ro'yxatda ko'rinishi uchun lokal hisoblanadi")
    }

    func testBodyText() {
        XCTAssertNil(Replay.bodyText(Data()))
        XCTAssertEqual(Replay.bodyText("ok".data(using: .utf8)!), "ok")
        XCTAssertEqual(Replay.bodyText(Data([0xFF, 0xFE, 0x00])), "(binary 3-byte body)")
    }
}

@MainActor
final class ReplayDiffStoreTests: XCTestCase {
    private func makeStore() -> LogStore {
        let store = LogStore()
        store.hideNoise = true
        store.followLatest = false
        store.slowOnly = false
        store.errorsOnly = false
        store.favoritesOnly = false
        store.favoriteKeys = []
        store.status = .all
        store.selectedMethod = "ALL"
        store.selectedAppId = "all"
        store.selectedSerial = nil
        store.selectedHost = nil
        store.query = ""
        store.isPaused = false
        store.replayConfirm = { _ in true }
        return store
    }

    private func log(_ key: String, method: String = "GET", path: String = "/api/a", ts: Double, body: String? = nil) -> NetworkLog {
        NetworkLog(key: key, method: method, url: "https://h.uz\(path)", api: "", responseCode: 200, serial: "S1", ts: ts, requestBody: body, responseBody: "{\"k\":\"\(key)\"}")
    }

    func testReplayInsertsSelectsAndOffersDiff() async {
        let store = makeStore()
        let original = log("a", ts: 1)
        store.ingestBatch([original])
        store.selectLog(original)
        let gate = expectation(description: "replay performed")
        store.replayPerformer = { _ in
            gate.fulfill()
            return ReplayResult(statusCode: 503, statusMessage: "Service Unavailable", body: "{\"k\":\"new\"}", durationMs: 12)
        }
        store.replaySelected()
        XCTAssertTrue(store.replayInFlight.contains("a"))
        XCTAssertFalse(store.canReplay(original), "yuborilayotganda ikkinchi marta bosilmaydi")
        await fulfillment(of: [gate], timeout: 2)
        for _ in 0..<50 where store.replayInFlight.contains("a") {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertFalse(store.replayInFlight.contains("a"))
        XCTAssertEqual(store.allLogs.count, 2)
        let replayed = store.allLogs.first { Replay.isReplay($0) }
        XCTAssertNotNil(replayed)
        XCTAssertEqual(store.selectedKey, replayed?.key)
        XCTAssertEqual(replayed?.responseCode, 503)
        XCTAssertTrue(store.visibleLogs.contains { $0.key == replayed?.key }, "replay ro'yxatda ko'rinadi")
        XCTAssertEqual(store.toast?.text, "Qayta yuborildi · 503 · 12 ms")
        XCTAssertEqual(store.toast?.actionTitle, "Asl bilan solishtirish")
        store.toast?.action?()
        XCTAssertEqual(store.diffPair?.a.key, "a")
        XCTAssertEqual(store.diffPair?.b.key, replayed?.key)
    }

    func testReplayWithoutSerialStaysVisible() async {
        let store = makeStore()
        let original = NetworkLog(key: "n", method: "GET", url: "https://h.uz/a", api: "", responseCode: 200, source: "logcat", ts: 1)
        store.ingestBatch([original])
        store.selectLog(original)
        store.replayPerformer = { _ in ReplayResult(statusCode: 200, durationMs: 1) }
        store.replaySelected()
        for _ in 0..<50 where store.replayInFlight.contains("n") {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        let replayed = store.allLogs.first { Replay.isReplay($0) }
        XCTAssertNotNil(replayed)
        XCTAssertTrue(store.visibleLogs.contains { $0.key == replayed?.key }, "serial'siz asl so'rov replay'i ham ro'yxatda")
    }

    func testReplayRefusesUnsendable() {
        let store = makeStore()
        let broken = NetworkLog(key: "b", method: "GET", url: "", api: "", serial: "S1", ts: 1)
        store.ingestBatch([broken])
        store.selectLog(broken)
        var called = false
        store.replayPerformer = { _ in called = true; return ReplayResult() }
        store.replaySelected()
        XCTAssertFalse(called)
        XCTAssertFalse(store.canReplay(broken))
        XCTAssertEqual(store.toast?.text, "URL bo'sh — qayta yuborib bo'lmaydi")
    }

    func testMutatingReplayRespectsConfirmation() {
        let store = makeStore()
        let post = log("p", method: "POST", ts: 1, body: "{}")
        store.ingestBatch([post])
        store.selectLog(post)
        var asked = 0
        var called = false
        store.replayConfirm = { _ in asked += 1; return false }
        store.replayPerformer = { _ in called = true; return ReplayResult() }
        store.replaySelected()
        XCTAssertEqual(asked, 1)
        XCTAssertFalse(called)
        XCTAssertTrue(store.replayInFlight.isEmpty)
        store.replayConfirm = { _ in asked += 1; return true }
        let get = log("g", method: "GET", ts: 2)
        store.ingestBatch([get])
        store.selectLog(get)
        store.replaySelected()
        XCTAssertEqual(asked, 1, "GET tasdiq so'ramaydi")
    }

    func testReplayIgnoresPause() async {
        let store = makeStore()
        let original = log("a", ts: 1)
        store.ingestBatch([original])
        store.selectLog(original)
        store.isPaused = true
        store.replayPerformer = { _ in ReplayResult(statusCode: 200, durationMs: 1) }
        store.replaySelected()
        for _ in 0..<50 where store.replayInFlight.contains("a") {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(store.allLogs.count, 2, "foydalanuvchining o'z amali pauzada ham darhol ko'rinadi")
        XCTAssertTrue(store.pendingWhilePaused.isEmpty)
    }

    func testDiffAnchorFlow() {
        let store = makeStore()
        let a = log("a", ts: 1)
        let b = log("b", ts: 2)
        let c = log("c", path: "/api/other", ts: 3)
        store.ingestBatch([a, b, c])
        store.selectLog(a)
        XCTAssertFalse(store.canCompareWithAnchor)
        store.toggleDiffAnchorSelected()
        XCTAssertEqual(store.diffAnchorKey, "a")
        XCTAssertFalse(store.canCompareWithAnchor, "A ning o'zi bilan solishtirilmaydi")
        store.compareSelectedWithAnchor()
        XCTAssertNil(store.diffPair)
        XCTAssertEqual(store.toast?.text, "Bu so'rov A ning o'zi — boshqasini tanlang")
        store.selectLog(c)
        XCTAssertTrue(store.canCompareWithAnchor)
        store.compareSelectedWithAnchor()
        XCTAssertEqual(store.diffPair?.a.key, "a")
        XCTAssertEqual(store.diffPair?.b.key, "c")
        store.swapDiff()
        XCTAssertEqual(store.diffPair?.a.key, "c")
        store.closeDiff()
        XCTAssertNil(store.diffPair)
        store.toggleDiffAnchor(a)
        XCTAssertNil(store.diffAnchorKey)
        store.selectLog(c)
        store.compareSelectedWithAnchor()
        XCTAssertEqual(store.toast?.text, "Avval A so'rovni belgilang (⌘D)")
    }

    func testCompareWithPreviousSameEndpoint() {
        let store = makeStore()
        let a = log("a", ts: 1)
        let b = log("b", ts: 2)
        let c = log("c", path: "/api/other", ts: 3)
        store.ingestBatch([a, b, c])
        store.selectLog(b)
        XCTAssertTrue(store.canCompareSelectedWithPrevious)
        store.compareSelectedWithPrevious()
        XCTAssertEqual(store.diffPair?.a.key, "a")
        XCTAssertEqual(store.diffPair?.b.key, "b")
        store.closeDiff()
        store.selectLog(c)
        XCTAssertFalse(store.canCompareSelectedWithPrevious)
        store.compareSelectedWithPrevious()
        XCTAssertNil(store.diffPair)
        XCTAssertEqual(store.toast?.text, "Shu endpointning oldingi chaqiruvi yo'q")
    }

    func testRenderedBodyBuildsTreeOnlyForJSONBodyTabs() {
        let json = NetworkLog(key: "j", method: "GET", url: "https://h.uz/a", api: "", serial: "S1", ts: 1, responseBody: "{\"a\":[1,2]}")
        var key = RenderedBody.Key(logKey: "j", tab: .response, redact: false, pretty: true, query: "", index: 0, tree: true)
        XCTAssertNotNil(RenderedBody.make(log: json, key: key).tree)
        key.tab = .headers
        XCTAssertNil(RenderedBody.make(log: json, key: key).tree)
        key.tab = .response
        key.tree = false
        XCTAssertNil(RenderedBody.make(log: json, key: key).tree)
        let text = NetworkLog(key: "t", method: "GET", url: "https://h.uz/a", api: "", serial: "S1", ts: 1, responseBody: "hello")
        key.tree = true
        let rendered = RenderedBody.make(log: text, key: key)
        XCTAssertNil(rendered.tree)
        XCTAssertEqual(rendered.text, "hello", "JSON bo'lmasa matn rejimi ishlaydi")
    }

    func testRenderedDiffAttributesLines() {
        let a = log("a", ts: 1)
        let b = log("b", ts: 2)
        let rendered = RenderedDiff.make(a: a, b: b, section: .response, redact: false, onlyChanges: false)
        XCTAssertEqual(rendered.diff.inserted, 1)
        XCTAssertTrue(rendered.unified.contains("- "))
        XCTAssertTrue(rendered.unified.contains("+ "))
        XCTAssertEqual(rendered.attributed.string.components(separatedBy: "\n").count, rendered.lines.count)
        let same = RenderedDiff.make(a: a, b: a, section: .response, redact: false, onlyChanges: true)
        XCTAssertTrue(same.diff.identical)
        XCTAssertEqual(same.attributed.length, 0)
    }

    func testSurfaceWiring() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        func src(_ rel: String) throws -> String {
            try String(contentsOf: root.appendingPathComponent(rel), encoding: .utf8)
        }
        let app = try src("Sources/LogX/LogXApp.swift")
        XCTAssertTrue(app.contains("\"Qayta yuborish\", #selector(replaySelected(_:)), \"\\r\", .command"))
        XCTAssertTrue(app.contains("#selector(toggleDiffAnchor(_:)), \"d\", .command"))
        XCTAssertTrue(app.contains("#selector(compareWithAnchor(_:)), \"d\", [.command, .shift]"))
        XCTAssertTrue(app.contains("#selector(compareWithPrevious(_:)), \"d\", [.command, .option]"))
        XCTAssertTrue(app.contains("case #selector(replaySelected(_:)):"))
        let content = try src("Sources/LogX/Views/ContentView.swift")
        XCTAssertTrue(content.contains(".sheet(item: Binding(get: { store.diffPair }"))
        XCTAssertTrue(content.contains("DiffView(pair: pair)"))
        let detail = try src("Sources/LogX/Views/RequestDetail.swift")
        XCTAssertTrue(detail.contains("@AppStorage(\"logx.treeBody\")"))
        XCTAssertTrue(detail.contains("JSONTreeView(tree: tree, query: findQuery, activeIndex: findIndex)"))
        XCTAssertTrue(detail.contains(".disabled(!store.canReplay(log))"))
        XCTAssertTrue(detail.contains(".keyboardShortcut(.return, modifiers: .command)"))
        let list = try src("Sources/LogX/Views/RequestList.swift")
        XCTAssertTrue(list.contains("Button(\"Qayta yuborish\") { store.replay(log) }"))
        XCTAssertTrue(list.contains("Oldingi bir xil so'rov bilan solishtirish"))
        let row = try src("Sources/LogX/Views/RequestRow.swift")
        XCTAssertTrue(row.contains("if Replay.isReplay(log) {"))
        XCTAssertTrue(row.contains("if store.diffAnchorKey == log.key {"))
        XCTAssertTrue(detail.contains("query: tree ? \"\" : findQuery"), "daraxt rejimida topish harfi tanani qayta qurmaydi")
        XCTAssertTrue(detail.contains("if treeAvailable != true {"), "daraxt ochiq bo'lsa Raw/O'rash pill'lari yashirin")
        let tree = try src("Sources/LogX/Views/JSONTreeView.swift")
        XCTAssertTrue(tree.contains("ScrollView(.vertical)"))
        XCTAssertFalse(tree.contains("[.vertical, .horizontal]"), "ikki o'qli ScrollView LazyVStack kengligini buzadi")
        XCTAssertTrue(tree.contains("let matches = tree.matches(query: query)"), "topilmalar bir renderda bir marta")
        XCTAssertTrue(tree.contains("Button(\"Yo'lni nusxalash\")"))
        XCTAssertTrue(tree.contains(".keyboardShortcut") == false, "daraxt global tezkor tugmalarni egallamaydi")
        let diff = try src("Sources/LogX/Views/DiffView.swift")
        XCTAssertTrue(diff.contains(".keyboardShortcut(.cancelAction)"))
        XCTAssertFalse(diff.contains("LinearGradient"))
    }
}
