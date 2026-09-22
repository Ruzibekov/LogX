import Foundation
import LogXCore

extension LogStore {
    func togglePause() {
        isPaused.toggle()
        if !isPaused, !pendingWhilePaused.isEmpty {
            let buffered = pendingWhilePaused
            pendingWhilePaused = []
            pausedCount = 0
            ingestBatch(buffered)
        }
        publishConnection()
    }

    func toggleSort(_ field: LogSortField) {
        if sortField == field {
            sortOrder = (sortOrder == .ascending) ? .descending : .ascending
        } else {
            sortField = field
            sortOrder = (field == .duration) ? .descending : .ascending
        }
        recomputeDerivedState()
    }

    /// Tozalash: kalitlar «suv belgisi» sifatida eslab qolinadi — qayta ulanishda
    /// serverning tail'i ularni qaytarsa ham ro'yxatga tushmaydi. Bekor qilish mumkin.
    func clearLogs() {
        guard !liveByKey.isEmpty || !pendingWhilePaused.isEmpty else { return }
        clearedSnapshot.merge(liveByKey) { _, new in new }
        for item in pendingWhilePaused { clearedSnapshot[item.key] = item }
        enforceSnapshotBudget()
        if clearedKeys.count > maxLogCapacity * 2 { clearedKeys.removeAll() }
        clearedKeys.formUnion(liveByKey.keys)
        clearedKeys.formUnion(pendingWhilePaused.map(\.key))
        let cleared = liveByKey.count + pendingWhilePaused.count
        liveByKey.removeAll()
        bodyBytesEstimate = 0
        pendingWhilePaused = []
        pausedCount = 0
        lastActivityTs = nil
        rebuildFromLive()
        selectedKey = nil
        selectedIsHidden = false
        flash("\(cleared) ta so'rov tozalandi", actionTitle: "Bekor qilish", ttl: 8) { [weak self] in self?.undoClear() }
    }

    var canUndoClear: Bool { !clearedSnapshot.isEmpty }

    func enforceSnapshotBudget() {
        if clearedSnapshot.count > maxLogCapacity {
            let extra = clearedSnapshot
                .sorted { ($0.value.ts ?? 0) < ($1.value.ts ?? 0) }
                .prefix(clearedSnapshot.count - maxLogCapacity)
            for entry in extra { clearedSnapshot.removeValue(forKey: entry.key) }
        }
        guard BodyBudget.totalBytes(clearedSnapshot.values) > BodyBudget.secondaryBodyBytes else { return }
        let newestFirst = clearedSnapshot.values.sorted { ($0.ts ?? 0) > ($1.ts ?? 0) }
        for log in BodyBudget.enforce(newestFirst: newestFirst) {
            clearedSnapshot[log.key] = log
        }
    }

    func undoClear() {
        guard canUndoClear else { return }
        for (key, log) in clearedSnapshot where liveByKey[key] == nil {
            upsertLive(log)
        }
        clearedSnapshot = [:]
        clearedKeys = []
        lastActivityTs = liveByKey.values.compactMap(\.ts).max()
        rebuildFromLive()
        reconcileSelection()
    }

    func clearSelection() {
        selectedKey = nil
    }

    /// Joriy tab tanasini (redakt holatiga mos) nusxalaydi; menyu ⌥⌘C shu yerga keladi.
    func copySelectedBody() {
        guard let log = selectedLog else { return }
        copy(JSONFormat.body(for: log, tab: detailTab, redact: redactEnabled), what: detailTab.title)
    }

    /// Nusxalashning yagona eshigi: bo'sh matn buferga tushmaydi, har holat aytiladi.
    func copy(_ text: String, what: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "—" else {
            flash("\(what) bo'sh — nusxalanmadi")
            return
        }
        CopyBox.plainText(text)
        flash("Nusxalandi · \(what)")
    }

    func flash(_ text: String, actionTitle: String? = nil, ttl: TimeInterval = 2.4, action: (() -> Void)? = nil) {
        toastTask?.cancel()
        let next = Toast(text: text, actionTitle: actionTitle, action: action)
        toast = next
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(ttl))
            guard !Task.isCancelled, let self, self.toast?.id == next.id else { return }
            self.toast = nil
        }
    }

    func dismissToast() {
        toastTask?.cancel()
        toast = nil
    }

    func dismissBanner() {
        setBanner(nil)
    }

    /// ⌘E / ⇧⌘E: ko'rinadigan ro'yxatda keyingi yoki oldingi xatoga o'tadi (4xx/5xx/NET).
    @discardableResult
    func moveToError(forward: Bool) -> Bool {
        let logs = visibleLogs
        guard !logs.isEmpty else { return false }
        let current = selectedKey.flatMap { key in logs.firstIndex(where: { $0.key == key }) }
        let count = logs.count
        let step = forward ? 1 : -1
        let origin = current ?? (forward ? -1 : count)
        let order = (1...count).map { offset in ((origin + step * offset) % count + count) % count }
        guard let idx = order.first(where: { logs[$0].statusClass.isFailure && $0 != current }) else {
            flash(forward ? "Keyingi xato yo'q" : "Oldingi xato yo'q")
            return false
        }
        selectLog(logs[idx])
        return true
    }

    /// Ro'yxat qidiruviga shu endpoint yo'lini qo'yadi — takrorlarni bir bosishda ajratadi.
    func filterEndpoint(_ log: NetworkLog) {
        let path = log.pathOnly
        guard !path.isEmpty else { return }
        applyQuery(query == path ? "" : path)
    }
}
