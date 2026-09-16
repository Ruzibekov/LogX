import Foundation
import LogXCore

extension LogStore {
    func selectDevice(_ serial: String?) {
        guard selectedSerial != serial else { return }
        selectedSerial = serial
        recomputeDerivedState()
        reconcileSelection()
        persistPrefs()
    }

    func selectAllDevices() {
        guard selectedSerial != nil else { return }
        selectedSerial = nil
        recomputeDerivedState()
        reconcileSelection()
        persistPrefs()
    }

    func toggleFavoritesOnly() {
        favoritesOnly.toggle()
        recomputeDerivedState()
        reconcileSelection()
    }

    func isFavorite(_ key: String) -> Bool {
        favoriteKeys.contains(FavoriteKey.hash(key))
    }

    func toggleFavorite(_ key: String) {
        let h = FavoriteKey.hash(key)
        if favoriteKeys.contains(h) {
            favoriteKeys.remove(h)
        } else {
            favoriteKeys.insert(h)
        }
        favoriteKeys = FavoriteKey.prune(favoriteKeys, live: Set(liveByKey.keys.map(FavoriteKey.hash)))
        UserDefaults.standard.set(Array(favoriteKeys), forKey: "logx.favoriteHashes")
        recomputeDerivedState()
        if favoritesOnly { reconcileSelection() }
    }

    func selectMethod(_ next: String) {
        selectedMethod = next
        recomputeDerivedState()
        reconcileSelection()
        persistPrefs()
    }

    func selectStatus(_ next: StatusClass) {
        status = next
        if errorsOnly { errorsOnly = false }
        recomputeDerivedState()
        reconcileSelection()
        persistPrefs()
    }

    /// Qidiruv matni darhol saqlanadi, og'ir filtr (body qidiruvi) esa
    /// yozish to'xtagach bir marta hisoblanadi.
    func applyQuery(_ next: String) {
        query = next
        queryTask?.cancel()
        if next.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            recomputeDerivedState()
            reconcileSelection()
            return
        }
        queryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(LogStore.queryDebounce * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.recomputeDerivedState()
            self.reconcileSelection()
        }
    }

    /// ↑/↓: ko'rinadigan ro'yxat bo'ylab yuradi; tanlov yo'q bo'lsa chetidan boshlaydi.
    func moveSelection(by delta: Int) {
        let logs = visibleLogs
        guard !logs.isEmpty else { return }
        let current = selectedKey.flatMap { key in logs.firstIndex(where: { $0.key == key }) }
        let next: Int
        if let current {
            next = min(max(current + delta, 0), logs.count - 1)
        } else {
            next = delta < 0 ? logs.count - 1 : 0
        }
        selectLog(logs[next])
    }
}
