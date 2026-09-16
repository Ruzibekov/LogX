import AppKit
import Foundation
import LogXCore

extension LogStore {
    var selectedIsReplaying: Bool {
        selectedKey.map { replayInFlight.contains($0) } ?? false
    }

    func canReplay(_ log: NetworkLog) -> Bool {
        (try? Replay.request(for: log)) != nil && !replayInFlight.contains(log.key)
    }

    func replaySelected() {
        guard let log = selectedLog else { return }
        replay(log)
    }

    /// So'rov Mac'dan qayta yuboriladi; javob ro'yxatga `replay` manbasi bilan
    /// tushadi va tanlanadi. Pauza uni to'xtatmaydi — bu foydalanuvchining o'z amali.
    func replay(_ log: NetworkLog) {
        guard !replayInFlight.contains(log.key) else { return }
        if let failure = replayBlocker(log) {
            flash(failure)
            return
        }
        if Replay.isMutating(log.method), !replayConfirm(log) { return }
        replayInFlight.insert(log.key)
        flash("Yuborilmoqda · \(log.method) \(log.pathOnly)", ttl: Replay.timeout)
        Task { [weak self] in
            guard let self else { return }
            let result = await self.replayPerformer(log)
            self.finishReplay(of: log, result: result)
        }
    }

    func replayBlocker(_ log: NetworkLog) -> String? {
        do {
            _ = try Replay.request(for: log)
            return nil
        } catch {
            return Replay.describe(error)
        }
    }

    func finishReplay(of original: NetworkLog, result: ReplayResult) {
        replayInFlight.remove(original.key)
        let key = Replay.keyPrefix + UUID().uuidString
        var replayed = Replay.log(from: result, original: original, key: key, ts: Date().timeIntervalSince1970 * 1000)
        if (replayed.serial ?? "").isEmpty { replayed.serial = "mac" }
        insertReplay(replayed)
        selectLog(replayed)
        let summary: String
        if let code = result.statusCode {
            summary = "Qayta yuborildi · \(code) · \(result.durationMs) ms"
        } else {
            summary = "Qayta yuborish xato · \(result.error ?? "noma'lum")"
        }
        flash(summary, actionTitle: "Asl bilan solishtirish", ttl: 8) { [weak self] in
            self?.compare(original, replayed)
        }
    }

    func openReplayComposer(_ log: NetworkLog) {
        replayComposerLog = log
    }

    func closeReplayComposer() {
        replayComposerLog = nil
    }

    func replayCustom(original: NetworkLog, method: String, url: URL, headers: [String: String], body: String?) {
        closeReplayComposer()
        flash("Yuborilmoqda · \(method) \(url.path)", ttl: Replay.timeout)
        Task { [weak self] in
            guard let self else { return }
            let result = await Replay.performCustom(method: method, url: url, headers: headers, body: body)
            self.finishCustomReplay(of: original, result: result, method: method, url: url.absoluteString, headers: headers, body: body)
        }
    }

    func finishCustomReplay(of original: NetworkLog, result: ReplayResult, method: String, url: String, headers: [String: String], body: String?) {
        let key = Replay.keyPrefix + UUID().uuidString
        var replayed = Replay.log(
            from: result,
            original: original,
            key: key,
            ts: Date().timeIntervalSince1970 * 1000,
            method: method,
            url: url,
            requestHeaders: headers,
            requestBody: body
        )
        if (replayed.serial ?? "").isEmpty { replayed.serial = "mac" }
        insertReplay(replayed)
        selectLog(replayed)
        let summary: String
        if let code = result.statusCode {
            summary = "Qayta yuborildi · \(code) · \(result.durationMs) ms"
        } else {
            summary = "Qayta yuborish xato · \(result.error ?? "noma'lum")"
        }
        flash(summary, actionTitle: "Asl bilan solishtirish", ttl: 8) { [weak self] in
            self?.compare(original, replayed)
        }
    }

    func insertReplay(_ log: NetworkLog) {
        liveByKey[log.key] = log
        if let ts = log.ts { lastActivityTs = max(lastActivityTs ?? 0, ts) }
        rebuildFromLive()
        reconcileSelection()
    }

    static func confirmMutatingReplay(_ log: NetworkLog) -> Bool {
        let alert = NSAlert()
        alert.messageText = "\(log.method.uppercased()) so'rovni qayta yuborasizmi?"
        alert.informativeText = "\(log.pathOnly)\n\nBu metod serverda o'zgarish qilishi mumkin (yozuv yaratish, o'chirish, to'lov). So'rov asl sarlavha va tana bilan ketadi."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Yuborish")
        alert.addButton(withTitle: "Bekor qilish")
        return alert.runModal() == .alertFirstButtonReturn
    }

    // MARK: - Solishtirish

    var diffAnchor: NetworkLog? {
        diffAnchorKey.flatMap { key in allLogs.first { $0.key == key } }
    }

    func toggleDiffAnchor(_ log: NetworkLog) {
        if diffAnchorKey == log.key {
            diffAnchorKey = nil
            flash("Belgi olib tashlandi")
        } else {
            diffAnchorKey = log.key
            flash("A sifatida belgilandi · boshqa so'rovda ⇧⌘D solishtiradi")
        }
    }

    func toggleDiffAnchorSelected() {
        guard let log = selectedLog else { return }
        toggleDiffAnchor(log)
    }

    var canCompareWithAnchor: Bool {
        guard let anchor = diffAnchor, let log = selectedLog else { return false }
        return anchor.key != log.key
    }

    func compareSelectedWithAnchor() {
        guard let log = selectedLog else { return }
        compareWithAnchor(log)
    }

    func compareWithAnchor(_ log: NetworkLog) {
        guard let anchor = diffAnchor else {
            flash("Avval A so'rovni belgilang (⌘D)")
            return
        }
        guard anchor.key != log.key else {
            flash("Bu so'rov A ning o'zi — boshqasini tanlang")
            return
        }
        compare(anchor, log)
    }

    func previousSameEndpoint(of log: NetworkLog) -> NetworkLog? {
        LogDiff.previousSameEndpoint(of: log, in: allLogs)
    }

    var canCompareSelectedWithPrevious: Bool {
        selectedLog.flatMap { previousSameEndpoint(of: $0) } != nil
    }

    func compareSelectedWithPrevious() {
        guard let log = selectedLog else { return }
        compareWithPrevious(log)
    }

    func compareWithPrevious(_ log: NetworkLog) {
        guard let previous = previousSameEndpoint(of: log) else {
            flash("Shu endpointning oldingi chaqiruvi yo'q")
            return
        }
        compare(previous, log)
    }

    func compare(_ a: NetworkLog, _ b: NetworkLog) {
        diffPair = DiffPair(a: a, b: b)
    }

    func swapDiff() {
        guard let pair = diffPair else { return }
        diffPair = DiffPair(a: pair.b, b: pair.a)
    }

    func closeDiff() {
        diffPair = nil
    }
}
