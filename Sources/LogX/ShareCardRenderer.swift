import AppKit
import LogXCore

enum ShareCardRenderer {
    static func image(log: NetworkLog, tab: DetailTab, redact: Bool = false) -> NSImage {
        var subject = log
        if redact {
            subject.requestHeaders = Redactor.mask(log.requestHeaders)
            subject.responseHeaders = Redactor.mask(log.responseHeaders)
        }
        let body = JSONFormat.body(for: subject, tab: tab, redact: redact)
        let spans = (tab == .headers || tab == .params) ? [JSONSpan(body, .plain)] : JSONFormat.highlight(body.isEmpty ? "—" : body)
        let caption = ShareCardRenderer.header(subject, redact: redact)
        let width: CGFloat = 920
        let pad: CGFloat = 28
        let mono = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let titleFont = NSFont.systemFont(ofSize: 15, weight: .semibold)
        let small = NSFont.systemFont(ofSize: 11, weight: .medium)

        let attrBody = NSMutableAttributedString()
        for span in spans {
            attrBody.append(NSAttributedString(string: span.text, attributes: [
                .font: mono,
                .foregroundColor: color(span.kind),
            ]))
        }
        if attrBody.length == 0 {
            attrBody.append(NSAttributedString(string: "—", attributes: [
                .font: mono,
                .foregroundColor: NSColor(rgbHex: 0x8C919B),
            ]))
        }

        let bodyRect = attrBody.boundingRect(
            with: NSSize(width: width - pad * 2, height: 8_000),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let height = min(max(220, bodyRect.height + 148), 1_600)
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor(rgbHex: 0x0C0E11).setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        NSColor(rgbHex: 0x1FB6D4).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 4, height: size.height)).fill()

        let title = NSAttributedString(string: caption.title, attributes: [
            .font: titleFont,
            .foregroundColor: NSColor(rgbHex: 0xECEFF3),
        ])
        title.draw(at: NSPoint(x: pad, y: size.height - 40))

        let meta = NSAttributedString(string: caption.meta, attributes: [
            .font: small,
            .foregroundColor: NSColor(rgbHex: 0x8C919B),
        ])
        meta.draw(in: NSRect(x: pad, y: size.height - 78, width: width - pad * 2, height: 32))

        let tabTitle = NSAttributedString(string: tab.title.uppercased(), attributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor(rgbHex: 0x63D3E8),
            .kern: 1.1,
        ])
        tabTitle.draw(at: NSPoint(x: pad, y: size.height - 104))

        attrBody.draw(with: NSRect(
            x: pad,
            y: 36,
            width: width - pad * 2,
            height: size.height - 148
        ), options: [.usesLineFragmentOrigin, .usesFontLeading])

        let brand = NSAttributedString(string: redact ? "LogX · yashirilgan" : "LogX", attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor(rgbHex: 0x8C919B),
        ])
        brand.draw(at: NSPoint(x: pad, y: 14))
        image.unlockFocus()
        return image
    }

    static func pngData(log: NetworkLog, tab: DetailTab, redact: Bool = false) -> Data? {
        let img = image(log: log, tab: tab, redact: redact)
        guard let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff)
        else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    private struct Header {
        var title: String
        var meta: String
    }

    static func headerMeta(_ log: NetworkLog, redact: Bool) -> String {
        header(log, redact: redact).meta
    }

    private static func header(_ log: NetworkLog, redact: Bool) -> Header {
        let code = log.responseCode.map(String.init) ?? "NET"
        let rawURL = log.url.isEmpty ? log.api : log.url
        let url = redact ? Redactor.maskURL(rawURL) : rawURL
        let app = log.appShortLabel == AppProfile.unknown.shortLabel ? "" : log.appShortLabel
        return Header(
            title: "\(log.method)  \(code)",
            meta: [url, app, log.device ?? log.deviceModel ?? ""].filter { !$0.isEmpty }.joined(separator: "  ·  ")
        )
    }

    private static func color(_ kind: JSONSpanKind) -> NSColor {
        JSONHighlighter.nsColor(kind)
    }
}
