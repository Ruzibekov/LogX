import Foundation

extension NetworkLog {
    public var fieldDeviceLabel: String {
        let raw = [device, deviceName, deviceModel]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        return raw ?? "—"
    }

    public var fieldDeviceId: String {
        let header = requestHeaders["device-id"]
            ?? requestHeaders["Device-Id"]
            ?? requestHeaders["x-device-id"]
        if let header, !header.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return header.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return fieldDeviceLabel.lowercased()
    }

    public var hostLabel: String {
        let raw = url.isEmpty ? api : url
        return URL(string: raw)?.host ?? ""
    }
}
