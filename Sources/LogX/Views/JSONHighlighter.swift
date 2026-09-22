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

    static func bodyFont(size: CGFloat = 11.5) -> NSFont {
        NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }
    static var bodyFont: NSFont { bodyFont(size: 11.5) }

    /// NSTextView uchun: rangli matn + faol topilma diapazoni (scroll uchun).
    static func nsAttributedString(
        for text: String,
        headers: Bool = false,
        highlights: [Range<String.Index>] = [],
        activeIndex: Int? = nil,
        fontSize: CGFloat = 11.5
    ) -> (text: NSAttributedString, activeRange: NSRange?) {
        let runs: [JSONRun]
        if headers {
            runs = JSONFormat.highlightHeaderRuns(text)
        } else if text.utf16.count > 120_000 {
            let cut = text.utf16.index(text.utf16.startIndex, offsetBy: 100_000)
            if let cutIndex = cut.samePosition(in: text) {
                let head = JSONFormat.highlightRuns(String(text[..<cutIndex]))
                let tailLength = text[cutIndex...].utf16.count
                runs = head + (tailLength > 0 ? [JSONRun(length: tailLength, kind: .plain)] : [])
            } else {
                runs = [JSONRun(length: text.utf16.count, kind: .plain)]
            }
        } else {
            runs = JSONFormat.highlightRuns(text)
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        let result = NSMutableAttributedString(string: text, attributes: [
            .font: bodyFont(size: fontSize),
            .foregroundColor: nsColor(.plain),
            .paragraphStyle: paragraph,
        ])
        result.beginEditing()
        var cursor = 0
        for run in runs {
            if run.kind != .plain, cursor + run.length <= result.length {
                result.addAttribute(.foregroundColor, value: nsColor(run.kind), range: NSRange(location: cursor, length: run.length))
            }
            cursor += run.length
        }
        result.endEditing()
        var active: NSRange?
        if !highlights.isEmpty {
            let warnBg = LogXTheme.dynamicNS(dark: 0xE0A23C, light: 0xA96B0C).withAlphaComponent(0.42)
            let accentBg = LogXTheme.dynamicNS(dark: 0x1FB6D4, light: 0x0A6073).withAlphaComponent(0.26)
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
        case .key: return LogXTheme.dynamicNS(dark: 0x7DD3FC, light: 0x0B5F86)
        case .string: return LogXTheme.dynamicNS(dark: 0xCE9178, light: 0x8F4A1E)
        case .number: return LogXTheme.dynamicNS(dark: 0x86EFAC, light: 0x146B3A)
        case .boolNull: return LogXTheme.dynamicNS(dark: 0xC586C0, light: 0x6B3FA0)
        case .punct: return LogXTheme.dynamicNS(dark: 0x94A3B8, light: 0x59626F)
        case .plain: return LogXTheme.dynamicNS(dark: 0xCBD5E1, light: 0x141821)
        }
    }

    static func spanColor(_ kind: JSONSpanKind) -> Color {
        Color(nsColor: nsColor(kind))
    }
}
