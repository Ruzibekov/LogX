import Compression
import Foundation

public struct PackedText: Equatable, Sendable {
    public static let packThreshold = 96

    private enum Store: Equatable, Sendable {
        case none
        case inline(String)
        case packed(Data, Int)
    }

    private var store: Store

    public init() { store = .none }

    public init(_ text: String?) {
        guard let text, !text.isEmpty else {
            store = .none
            return
        }
        let count = text.utf8.count
        guard count > PackedText.packThreshold, let packed = PackedText.pack(text) else {
            store = .inline(text)
            return
        }
        store = .packed(packed, count)
    }

    public var text: String? {
        switch store {
        case .none: return nil
        case .inline(let text): return text
        case .packed(let data, let count): return PackedText.unpack(data, byteCount: count)
        }
    }

    public var isEmpty: Bool {
        switch store {
        case .none: return true
        case .inline(let text): return text.isEmpty
        case .packed(_, let count): return count == 0
        }
    }

    public var byteCount: Int {
        switch store {
        case .none: return 0
        case .inline(let text): return text.utf8.count
        case .packed(_, let count): return count
        }
    }

    public var storedBytes: Int {
        switch store {
        case .none: return 0
        case .inline(let text): return text.utf8.count > 15 ? text.utf8.count : 0
        case .packed(let data, _): return data.count
        }
    }

    public func contains(_ needle: String) -> Bool {
        guard !needle.isEmpty, let text, !text.isEmpty else { return false }
        return text.range(of: needle, options: .caseInsensitive) != nil
    }

    private static func pack(_ text: String) -> Data? {
        var text = text
        return text.withUTF8 { input -> Data? in
            guard let source = input.baseAddress, input.count > 0 else { return nil }
            let limit = input.count
            let destination = UnsafeMutablePointer<UInt8>.allocate(capacity: limit)
            defer { destination.deallocate() }
            let written = compression_encode_buffer(destination, limit, source, limit, nil, COMPRESSION_LZFSE)
            guard written > 0, written < limit else { return nil }
            return Data(bytes: destination, count: written)
        }
    }

    private static func unpack(_ data: Data, byteCount: Int) -> String? {
        guard byteCount > 0 else { return "" }
        let destination = UnsafeMutablePointer<UInt8>.allocate(capacity: byteCount)
        defer { destination.deallocate() }
        let written = data.withUnsafeBytes { raw -> Int in
            guard let base = raw.baseAddress else { return 0 }
            return compression_decode_buffer(
                destination, byteCount,
                base.assumingMemoryBound(to: UInt8.self), raw.count,
                nil, COMPRESSION_LZFSE
            )
        }
        guard written == byteCount else { return nil }
        return String(decoding: UnsafeBufferPointer(start: destination, count: written), as: UTF8.self)
    }
}

public struct PackedHeaders: Equatable, Sendable {
    private static let pairSeparator: Character = "\u{1}"
    private static let lineSeparator: Character = "\u{2}"

    private var packed: PackedText

    public init() { packed = PackedText() }

    public init(_ map: [String: String]) {
        guard !map.isEmpty else {
            packed = PackedText()
            return
        }
        var flat = ""
        flat.reserveCapacity(map.reduce(0) { $0 + $1.key.utf8.count + $1.value.utf8.count + 2 })
        for key in map.keys.sorted() {
            if !flat.isEmpty { flat.append(PackedHeaders.lineSeparator) }
            flat += key
            flat.append(PackedHeaders.pairSeparator)
            flat += map[key] ?? ""
        }
        packed = PackedText(flat)
    }

    public var map: [String: String] {
        guard let flat = packed.text, !flat.isEmpty else { return [:] }
        var out: [String: String] = [:]
        for line in flat.split(separator: PackedHeaders.lineSeparator, omittingEmptySubsequences: false) {
            guard let split = line.firstIndex(of: PackedHeaders.pairSeparator) else { continue }
            out[String(line[..<split])] = String(line[line.index(after: split)...])
        }
        return out
    }

    public var isEmpty: Bool { packed.isEmpty }
    public var storedBytes: Int { packed.storedBytes }
    public func contains(_ needle: String) -> Bool { packed.contains(needle) }
}
