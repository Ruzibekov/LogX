import Foundation

public enum OpaqueStringElider {
    public static let minLength = 160
    public static let keep = 48

    public static func elide(_ text: String, minLength: Int = minLength, keep: Int = keep) -> String {
        let bytes = Array(text.utf8)
        guard bytes.count > minLength else { return text }
        let quote = UInt8(ascii: "\"")
        let backslash = UInt8(ascii: "\\")
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count)
        var changed = false
        var i = 0
        while i < bytes.count {
            let b = bytes[i]
            guard b == quote else {
                out.append(b)
                i += 1
                continue
            }
            let start = i + 1
            var j = start
            var opaque = true
            while j < bytes.count, bytes[j] != quote {
                if bytes[j] == backslash {
                    if j + 1 < bytes.count, bytes[j + 1] == UInt8(ascii: "n") || bytes[j + 1] == UInt8(ascii: "t") { opaque = false }
                    j += 2
                    continue
                }
                if bytes[j] <= 0x20 { opaque = false }
                j += 1
            }
            let end = min(j, bytes.count)
            out.append(quote)
            if opaque, end - start > minLength {
                var cut = start + keep
                while cut > start, bytes[cut] & 0xC0 == 0x80 { cut -= 1 }
                var slashes = 0
                var k = cut - 1
                while k >= start, bytes[k] == backslash { slashes += 1; k -= 1 }
                if slashes % 2 == 1 { cut -= 1 }
                out.append(contentsOf: bytes[start..<cut])
                out.append(contentsOf: Array("…".utf8))
                changed = true
            } else {
                out.append(contentsOf: bytes[start..<end])
            }
            if end < bytes.count { out.append(quote) }
            i = end + 1
        }
        return changed ? String(decoding: out, as: UTF8.self) : text
    }
}
