import Foundation
import LogXCore

extension LogStore {
    func reclaimAdb() {
        guard adbConflict != nil, !adbReclaimInFlight else { return }
        adbReclaimInFlight = true
        Task { [weak self] in
            guard let self else { return }
            defer { self.adbReclaimInFlight = false }
            do {
                let state = try await self.client.reclaimAdb()
                self.adbConflict = state.adbConflict
                if state.ok == false {
                    self.flash("Bo'shatilmadi: \(state.error ?? "adb xatosi")")
                } else if state.devices.isEmpty {
                    self.flash("adb qayta ishga tushdi — qurilma hali ko'rinmadi")
                } else {
                    self.flash("Qurilma bo'shatildi · \(state.devices[0].title)")
                }
            } catch {
                self.flash("Bo'shatilmadi: \(error)")
            }
            await self.refresh(full: true)
        }
    }
}
