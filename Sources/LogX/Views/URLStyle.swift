import Foundation
import SwiftUI
import LogXCore

enum URLInk: Equatable {
    case primary
    case muted
}

enum URLStyle {
    static func ink(for kind: URLSpanKind) -> URLInk {
        switch kind {
        case .pathPrefix, .pathEndpoint, .plain: return .primary
        case .scheme, .host, .port, .queryMark, .paramKey, .paramEquals, .paramValue, .paramAmp, .fragment: return .muted
        }
    }

    static func runs(_ raw: String) -> [(text: String, ink: URLInk)] {
        var out: [(text: String, ink: URLInk)] = []
        for span in URLHighlighter.tokenize(raw) {
            let ink = ink(for: span.kind)
            if let last = out.last, last.ink == ink {
                out[out.count - 1].text += span.text
            } else {
                out.append((span.text, ink))
            }
        }
        return out
    }

    private struct Key: Hashable {
        let text: String
        let size: CGFloat
        let weight: CGFloat
    }

    static let capacity = 512
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [Key: AttributedString] = [:]

    static func attributed(_ raw: String, size: CGFloat, weight: Font.Weight = .medium) -> AttributedString {
        let key = Key(text: raw, size: size, weight: LogXFonts.axisWeight(weight))
        lock.lock()
        if let hit = cache[key] {
            lock.unlock()
            return hit
        }
        lock.unlock()
        var result = AttributedString()
        for run in runs(raw) {
            var piece = AttributedString(run.text)
            piece.font = LogXType.ui(size, weight)
            piece.foregroundColor = run.ink == .primary ? LogXTheme.text : LogXTheme.muted
            result.append(piece)
        }
        lock.lock()
        if cache.count >= capacity { cache.removeAll(keepingCapacity: true) }
        cache[key] = result
        lock.unlock()
        return result
    }

    static func clearCache() {
        lock.lock()
        cache.removeAll()
        lock.unlock()
    }
}
