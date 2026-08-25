import Foundation

public enum StreamHealth: Equatable, Sendable {
    case idle
    case connecting
    case live
    case reconnecting(attempt: Int, nextDelay: TimeInterval)
    case failed(String)

    public var isLive: Bool {
        self == .live
    }

    public var isReconnecting: Bool {
        if case .reconnecting = self { return true }
        return false
    }
}

public enum ReconnectBackoff: Sendable {
    public static let initial: TimeInterval = 0.4
    public static let maxDelay: TimeInterval = 8

    public static func next(_ current: TimeInterval) -> TimeInterval {
        let base = current > 0 ? current : initial
        return min(base * 2, maxDelay)
    }
}

public enum LiveStreamURL {
    private static let serialAllowed: CharacterSet = {
        CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
    }()

    public static func httpStream(base: URL, serial: String, tail: Int = 80) -> URL? {
        guard var comps = URLComponents(url: base, resolvingAgainstBaseURL: true) else { return nil }
        let basePath = comps.path
        comps.path = basePath.hasSuffix("/") ? basePath + "api/http-stream" : basePath + "/api/http-stream"
        let encodedSerial = serial.addingPercentEncoding(withAllowedCharacters: serialAllowed) ?? serial
        comps.percentEncodedQuery = "serial=\(encodedSerial)&tail=\(tail)"
        return comps.url
    }
}

public enum AppConnection: Equatable, Sendable {
    case booting
    case serverDown
    case noDevice
    case connecting
    case live
    case reconnecting
    case paused

    public var title: String {
        switch self {
        case .booting: return "yuklanmoqda"
        case .serverDown: return "8787 · yo'q"
        case .noDevice: return "8787 · USB yo'q"
        case .connecting: return "8787 · ulanmoqda"
        case .live: return "8787 · jonli"
        case .reconnecting: return "8787 · qayta"
        case .paused: return "8787 · pauza"
        }
    }

    public var subtitle: String {
        switch self {
        case .booting: return "Monitor tekshirilmoqda"
        case .serverDown: return "Monitor ishlamayapti"
        case .noDevice: return "Telefonni ulang"
        case .connecting: return "Stream ochilmoqda"
        case .live: return "USB stream faol"
        case .reconnecting: return "Stream tiklanmoqda"
        case .paused: return "Yangi so'rovlar kutilmoqda"
        }
    }
}

public enum AppConnectionResolver {
    public static func resolve(
        isLoading: Bool,
        serverOK: Bool,
        isPaused: Bool,
        deviceCount: Int,
        streams: [StreamHealth]
    ) -> AppConnection {
        if isLoading && !serverOK { return .booting }
        if !serverOK { return .serverDown }
        if isPaused { return .paused }
        if deviceCount == 0 { return .noDevice }
        if streams.contains(where: \.isLive) { return .live }
        if streams.contains(where: \.isReconnecting) { return .reconnecting }
        return .connecting
    }
}

public enum LiveLogDecoder: Sendable {
    public static func decode(_ raw: String, serial: String) -> NetworkLog? {
        guard let data = raw.data(using: .utf8) else { return nil }
        guard let env = try? JSONDecoder().decode(LogEnvelope.self, from: data) else { return nil }
        var log = env.value.asLog(key: env.key)
        if log.serial?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            log.serial = serial
        }
        return log
    }
}

public enum LiveStreamChunk: Sendable {
    case opened
    case logs([NetworkLog])
}

public enum LiveStreamPump: Sendable {
    public static func run(
        request: URLRequest,
        serial: String,
        onChunk: @escaping @Sendable (LiveStreamChunk) async -> Void
    ) async throws {
        let (bytes, response) = try await MonitorSessions.stream.bytes(for: request)
        try Task.checkCancellation()
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw MonitorClientError.http(code) }
        await onChunk(.opened)

        var sse = SSEDecoder()
        var batch: [NetworkLog] = []
        var lastFlush = Date()

        for try await line in SSELineReader(bytes: bytes) {
            try Task.checkCancellation()
            guard let event = sse.feed(line: line) else { continue }
            if event.event == "meta" { continue }
            guard event.event == "http" else { continue }
            guard let item = LiveLogDecoder.decode(event.data, serial: serial) else { continue }
            batch.append(item)
            let now = Date()
            if batch.count >= 20 || now.timeIntervalSince(lastFlush) >= 0.05 {
                let out = batch
                batch.removeAll(keepingCapacity: true)
                lastFlush = now
                await onChunk(.logs(out))
            }
        }
        if !batch.isEmpty {
            await onChunk(.logs(batch))
        }
    }
}
