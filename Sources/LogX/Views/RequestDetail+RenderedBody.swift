import AppKit
import Foundation
import LogXCore

/// Bitta tabning tayyor ko'rinishi: matn, rangli NSAttributedString va topilmalar soni.
struct RenderedBody {
    struct Key: Equatable {
        var logKey: String
        var tab: DetailTab
        var redact: Bool
        var pretty: Bool
        var query: String
        var index: Int
        var tree: Bool
        var fontSize: CGFloat = 11.5

        init(logKey: String, tab: DetailTab, redact: Bool, pretty: Bool, query: String, index: Int, tree: Bool, fontSize: CGFloat = 11.5) {
            self.logKey = logKey
            self.tab = tab
            self.redact = redact
            self.pretty = pretty
            self.query = query
            self.index = index
            self.tree = tree
            self.fontSize = fontSize
        }
    }

    /// Shundan katta tana ekranda qisqartiriladi (nusxa to'liq qoladi) — NSTextView
    /// megabaytlik JSON'ni layout qilib UI'ni muzlatmasin.
    static let displayLimitBytes = 512 * 1024

    var key: Key
    var text: String
    var attributed: NSAttributedString
    var matchCount: Int
    var activeRange: NSRange?
    var truncationNotice: String?
    var tree: JSONTree?

    static func make(log: NetworkLog, key: Key) -> RenderedBody {
        if key.tree, key.tab == .request || key.tab == .response {
            let source = JSONFormat.body(for: log, tab: key.tab, redact: key.redact, pretty: true)
            if let tree = JSONTree(text: source, identity: "\(log.key)|\(key.tab.rawValue)|\(key.redact)") {
                return RenderedBody(key: key, text: source, attributed: NSAttributedString(), matchCount: 0, activeRange: nil, truncationNotice: nil, tree: tree)
            }
        }
        let body = JSONFormat.body(for: log, tab: key.tab, redact: key.redact, pretty: key.pretty)
        var display = body.isEmpty ? "—" : body
        var notice: String?
        if display.utf8.count > displayLimitBytes {
            let cut = String(decoding: display.utf8.prefix(displayLimitBytes), as: UTF8.self)
            let hidden = display.utf8.count - cut.utf8.count
            display = cut + "\n…"
            notice = "Ekranda \(ByteSize.label(displayLimitBytes)) ko'rsatildi, \(ByteSize.label(hidden)) qisqartirildi — «Nusxa» to'liq tanani beradi."
        }
        let matches = JSONFind.matches(display, query: key.query)
        let active = matches.isEmpty ? nil : min(max(key.index, 0), matches.count - 1)
        let rendered = JSONHighlighter.nsAttributedString(
            for: display,
            headers: key.tab == .headers,
            highlights: matches,
            activeIndex: active,
            fontSize: key.fontSize
        )
        return RenderedBody(
            key: key,
            text: body,
            attributed: rendered.text,
            matchCount: matches.count,
            activeRange: rendered.activeRange,
            truncationNotice: notice
        )
    }
}
