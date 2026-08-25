import AppKit
import SwiftUI
import LogXCore

enum JSONHighlighter {
    private static let monoFont = NSFont.monospacedSystemFont(ofSize: 11.5, weight: .regular)

    static func attributedString(for text: String, headers: Bool) -> AttributedString {
        if text.isEmpty { return AttributedString("") }
        
        let spans: [JSONSpan]
        if headers {
            spans = JSONFormat.highlightHeaders(text)
        } else {
            if text.count > 120_000 {
                let prefixIndex = text.index(text.startIndex, offsetBy: 100_000)
                let prefixSpans = JSONFormat.highlight(String(text[..<prefixIndex]))
                let suffixSpan = JSONSpan(String(text[prefixIndex...]), .plain)
                spans = prefixSpans + [suffixSpan]
            } else {
                spans = JSONFormat.highlight(text)
            }
        }
        
        let nsAttr = NSMutableAttributedString()
        for span in spans {
            nsAttr.append(NSAttributedString(
                string: span.text,
                attributes: [
                    .foregroundColor: nsColor(span.kind),
                    .font: monoFont
                ]
            ))
        }
        return AttributedString(nsAttr)
    }

    static func nsColor(_ kind: JSONSpanKind) -> NSColor {
        switch kind {
        case .key: return NSColor(srgbRed: 0.063, green: 0.725, blue: 0.506, alpha: 1)
        case .string: return NSColor(srgbRed: 0.220, green: 0.741, blue: 0.973, alpha: 1)
        case .number: return NSColor(srgbRed: 0.961, green: 0.620, blue: 0.043, alpha: 1)
        case .boolNull: return NSColor(srgbRed: 0.957, green: 0.247, blue: 0.369, alpha: 1) // Rose #F43F5E
        case .punct: return NSColor(srgbRed: 0.392, green: 0.455, blue: 0.545, alpha: 1)
        case .plain: return NSColor(srgbRed: 0.886, green: 0.914, blue: 0.945, alpha: 1)
        }
    }

    static func spanColor(_ kind: JSONSpanKind) -> Color {
        Color(nsColor: nsColor(kind))
    }
}
