import Foundation

/// Bitta tayyor SSE event'i.
public struct SSEEvent: Equatable, Sendable {
    public var event: String
    public var data: String

    public init(event: String, data: String) {
        self.event = event
        self.data = data
    }
}

/// Qatorlab beriladigan SSE parser.
/// `URLSession.AsyncBytes.lines` bo'sh qatorlarni tashlab yuboradi — SSE
/// event'lari esa aynan bo'sh qator bilan tugagani uchun parsing shu yerga
/// ko'chirildi: qatorlar (bo'shlari bilan) `feed(line:)` orqali beriladi.
public struct SSEDecoder: Sendable {
    private var event = ""
    private var dataLines: [String] = []

    public init() {}

    /// Bitta xom qatorni (yakundagi `\n` siz) beradi. Qator event'ni yopadigan
    /// bo'sh qator bo'lsa — tayyor `SSEEvent` qaytaradi.
    public mutating func feed(line: String) -> SSEEvent? {
        if line.isEmpty || line == "\r" {
            let out = dataLines.isEmpty ? nil : SSEEvent(event: event, data: dataLines.joined(separator: "\n"))
            event = ""
            dataLines = []
            return out
        }
        if line.hasPrefix(":") { return nil }
        if line.hasPrefix("event:") {
            event = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if line.hasPrefix("data:") {
            dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}

public enum SSEBufferStep: Equatable, Sendable {
    case pending
    case line(String)
    case dropped
}

public struct SSEPendingBuffer: Sendable {
    public static let defaultMaxBytes = 1_048_576

    private let maxBytes: Int
    private var pending: [UInt8] = []
    private var dropping = false

    public init(maxBytes: Int = SSEPendingBuffer.defaultMaxBytes) {
        self.maxBytes = maxBytes
    }

    public mutating func push(_ byte: UInt8) -> SSEBufferStep {
        if byte == 0x0A {
            if dropping {
                dropping = false
                pending.removeAll(keepingCapacity: true)
                return .dropped
            }
            let line = String(decoding: pending, as: UTF8.self)
            pending.removeAll(keepingCapacity: true)
            return .line(line)
        }
        if dropping { return .pending }
        if pending.count >= maxBytes {
            dropping = true
            pending.removeAll(keepingCapacity: true)
            return .pending
        }
        pending.append(byte)
        return .pending
    }

    public mutating func flushTail() -> String? {
        defer {
            pending.removeAll()
            dropping = false
        }
        if dropping || pending.isEmpty { return nil }
        return String(decoding: pending, as: UTF8.self)
    }
}

public struct SSELineReader: AsyncSequence, Sendable {
    public typealias Element = String
    let bytes: URLSession.AsyncBytes

    public init(bytes: URLSession.AsyncBytes) {
        self.bytes = bytes
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        var inner: URLSession.AsyncBytes.AsyncIterator
        var buffer = SSEPendingBuffer()

        init(inner: URLSession.AsyncBytes.AsyncIterator) {
            self.inner = inner
        }

        public mutating func next() async throws -> String? {
            while let byte = try await inner.next() {
                switch buffer.push(byte) {
                case .pending, .dropped:
                    continue
                case .line(let line):
                    return line
                }
            }
            return buffer.flushTail()
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(inner: bytes.makeAsyncIterator())
    }
}
