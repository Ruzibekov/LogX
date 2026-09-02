import Foundation

extension NetworkLog {
    public var fieldDeviceLabel: String {
        let raw = [device, deviceName, deviceModel]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        return raw ?? "—"
    }
}
