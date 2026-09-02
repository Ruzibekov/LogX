import Foundation

public enum StreamHealth: Equatable, Sendable {
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

    /// Shuncha soniya tirik turgan oqim «barqaror» sanaladi va uzilishdan keyin
    /// kutish boshidan boshlanadi; undan qisqa yashagan oqim (server darhol
    /// yopadigan holat) kutishni oshirib boradi — tez aylanma bo'lmaydi.
    public static let stableAfter: TimeInterval = 5

    public static func next(_ current: TimeInterval) -> TimeInterval {
        let base = current > 0 ? current : initial
        return min(base * 2, maxDelay)
    }

    /// Uzilishdan keyin qancha kutish: `connectedFor` — oqim qancha yashagani.
    public static func afterDrop(current: TimeInterval, connectedFor: TimeInterval) -> TimeInterval {
        if connectedFor >= stableAfter || current <= 0 { return initial }
        return next(current)
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
    /// Server `event: error` yubordi (masalan, qurilma uzildi) — oqim hali ochiq.
    case serverError(String)
}

/// Loglarni 20 tagacha yoki 50 ms gacha to'plab, keyin bittada beradi. Taymer
/// mustaqil ishlaydi — oxirgi log keyingi http hodisasini kutmaydi.
actor LogBatcher {
    static let maxCount = 20
    static let maxDelayNanos: UInt64 = 50_000_000

    private var items: [NetworkLog] = []
    private var timer: Task<Void, Never>?
    private var flushing = false
    private let sink: @Sendable ([NetworkLog]) async -> Void

    init(sink: @escaping @Sendable ([NetworkLog]) async -> Void) {
        self.sink = sink
    }

    func add(_ log: NetworkLog) async {
        items.append(log)
        if items.count >= Self.maxCount {
            await flushNow()
            return
        }
        guard timer == nil else { return }
        timer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: LogBatcher.maxDelayNanos)
            guard !Task.isCancelled else { return }
            await self?.timerFired()
        }
    }

    private func timerFired() async {
        timer = nil
        await flushNow()
    }

    func flushNow() async {
        timer?.cancel()
        timer = nil
        guard !flushing else { return }
        flushing = true
        defer { flushing = false }
        while !items.isEmpty {
            let out = items
            items.removeAll(keepingCapacity: true)
            await sink(out)
        }
    }

    var pendingCount: Int { items.count }
}

/// Oqimdan oxirgi bayt qachon kelganini saqlaydi — jim o'lgan ulanishni aniqlash uchun.
actor StreamPulse {
    private var last = Date()

    func beat() {
        last = Date()
    }

    func idle(now: Date = Date()) -> TimeInterval {
        now.timeIntervalSince(last)
    }
}

public enum LiveStreamPump: Sendable {
    /// Server har 15 s `: ping` yuboradi; shuncha vaqt hech narsa kelmasa ulanish
    /// o'lgan sanaladi (uyqudan keyin TCP FIN kelmaydigan holat).
    public static let idleTimeout: TimeInterval = 45

    public static func run(
        request: URLRequest,
        serial: String,
        idleTimeout: TimeInterval = LiveStreamPump.idleTimeout,
        onChunk: @escaping @Sendable (LiveStreamChunk) async -> Void
    ) async throws {
        let (bytes, response) = try await MonitorSessions.stream.bytes(for: request)
        try Task.checkCancellation()
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw MonitorClientError.http(code) }
        await onChunk(.opened)

        let pulse = StreamPulse()
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await consume(bytes: bytes, serial: serial, pulse: pulse, onChunk: onChunk)
            }
            group.addTask {
                let step = max(1, min(5, idleTimeout / 3))
                while true {
                    try await Task.sleep(nanoseconds: UInt64(step * 1_000_000_000))
                    if await pulse.idle() >= idleTimeout {
                        throw MonitorClientError.idle(Int(idleTimeout))
                    }
                }
            }
            try await group.next()
            group.cancelAll()
        }
    }

    private static func consume(
        bytes: URLSession.AsyncBytes,
        serial: String,
        pulse: StreamPulse,
        onChunk: @escaping @Sendable (LiveStreamChunk) async -> Void
    ) async throws {
        var sse = SSEDecoder()
        let batcher = LogBatcher { logs in await onChunk(.logs(logs)) }
        defer { Task { await batcher.flushNow() } }

        for try await line in SSELineReader(bytes: bytes) {
            try Task.checkCancellation()
            await pulse.beat()
            guard let event = sse.feed(line: line) else { continue }
            if event.event == "error" {
                await onChunk(.serverError(event.data))
                continue
            }
            guard event.event == "http" else { continue }
            guard let item = LiveLogDecoder.decode(event.data, serial: serial) else { continue }
            await batcher.add(item)
        }
        await batcher.flushNow()
    }
}
