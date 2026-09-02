import AppKit
import SwiftUI
import LogXCore

enum JSONHighlighter {
    static func attributedString(
        for text: String,
        headers: Bool,
        highlights: [Range<String.Index>] = [],
        activeIndex: Int? = nil
    ) -> AttributedString {
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

        var result = AttributedString()
        result.font = .system(size: 11.5, design: .monospaced)
        for span in spans {
            var piece = AttributedString(span.text)
            piece.font = .system(size: 11.5, design: .monospaced)
            piece.foregroundColor = spanColor(span.kind)
            result.append(piece)
        }
        if !highlights.isEmpty {
            let warnBg = LogXTheme.warn.opacity(0.42)
            let accentBg = LogXTheme.accent.opacity(0.26)
            for (i, range) in highlights.enumerated() {
                let nsRange = NSRange(range, in: text)
                guard nsRange.location != NSNotFound,
                      let attrRange = Range<AttributedString.Index>(nsRange, in: result) else { continue }
                result[attrRange].backgroundColor = i == activeIndex ? warnBg : accentBg
            }
        }
        return result
    }

    static let bodyFont = NSFont.monospacedSystemFont(ofSize: 11.5, weight: .regular)

    /// NSTextView uchun: rangli matn + faol topilma diapazoni (scroll uchun).
    static func nsAttributedString(
        for text: String,
        headers: Bool,
        highlights: [Range<String.Index>] = [],
        activeIndex: Int? = nil
    ) -> (text: NSAttributedString, activeRange: NSRange?) {
        let spans: [JSONSpan]
        if headers {
            spans = JSONFormat.highlightHeaders(text)
        } else if text.count > 120_000 {
            let prefixIndex = text.index(text.startIndex, offsetBy: 100_000)
            spans = JSONFormat.highlight(String(text[..<prefixIndex])) + [JSONSpan(String(text[prefixIndex...]), .plain)]
        } else {
            spans = JSONFormat.highlight(text)
        }
        let result = NSMutableAttributedString()
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        for span in spans {
            result.append(NSAttributedString(string: span.text, attributes: [
                .font: bodyFont,
                .foregroundColor: nsColor(span.kind),
                .paragraphStyle: paragraph,
            ]))
        }
        var active: NSRange?
        if !highlights.isEmpty {
            let warnBg = NSColor(srgbRed: 0.878, green: 0.651, blue: 0.231, alpha: 0.42)
            let accentBg = NSColor(srgbRed: 0.357, green: 0.553, blue: 0.937, alpha: 0.26)
            for (i, range) in highlights.enumerated() {
                let nsRange = NSRange(range, in: text)
                guard nsRange.location != NSNotFound, nsRange.location + nsRange.length <= result.length else { continue }
                result.addAttribute(.backgroundColor, value: i == activeIndex ? warnBg : accentBg, range: nsRange)
                if i == activeIndex { active = nsRange }
            }
        }
        return (result, active)
    }

    static func nsColor(_ kind: JSONSpanKind) -> NSColor {
        switch kind {
        case .key: return NSColor(srgbRed: 0.878, green: 0.890, blue: 0.910, alpha: 1)    // #E0E3E8
        case .string: return NSColor(srgbRed: 0.541, green: 0.690, blue: 0.961, alpha: 1) // #8AB0F5
        case .number: return NSColor(srgbRed: 0.878, green: 0.651, blue: 0.231, alpha: 1) // #E0A63B
        case .boolNull: return NSColor(srgbRed: 0.239, green: 0.745, blue: 0.478, alpha: 1) // #3DBE7A
        case .punct: return NSColor(srgbRed: 0.549, green: 0.569, blue: 0.604, alpha: 1)  // #8C919A
        case .plain: return NSColor(srgbRed: 0.788, green: 0.800, blue: 0.824, alpha: 1)  // #C9CCD2
        }
    }

    static func spanColor(_ kind: JSONSpanKind) -> Color {
        Color(nsColor: nsColor(kind))
    }
}
