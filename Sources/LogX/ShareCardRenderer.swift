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
                .foregroundColor: NSColor(srgbRed: 0.549, green: 0.569, blue: 0.604, alpha: 1),
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
        NSColor(srgbRed: 0.059, green: 0.063, blue: 0.071, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        NSColor(srgbRed: 0.357, green: 0.553, blue: 0.937, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 4, height: size.height)).fill()

        let title = NSAttributedString(string: caption.title, attributes: [
            .font: titleFont,
            .foregroundColor: NSColor(srgbRed: 0.949, green: 0.953, blue: 0.961, alpha: 1),
        ])
        title.draw(at: NSPoint(x: pad, y: size.height - 40))

        let meta = NSAttributedString(string: caption.meta, attributes: [
            .font: small,
            .foregroundColor: NSColor(srgbRed: 0.549, green: 0.569, blue: 0.604, alpha: 1),
        ])
        meta.draw(in: NSRect(x: pad, y: size.height - 78, width: width - pad * 2, height: 32))

        let tabTitle = NSAttributedString(string: tab.title.uppercased(), attributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor(srgbRed: 0.541, green: 0.690, blue: 0.961, alpha: 1),
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
            .foregroundColor: NSColor(srgbRed: 0.549, green: 0.569, blue: 0.604, alpha: 1),
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
        switch kind {
        case .key: return NSColor(srgbRed: 0.878, green: 0.890, blue: 0.910, alpha: 1)
        case .string: return NSColor(srgbRed: 0.541, green: 0.690, blue: 0.961, alpha: 1)
        case .number: return NSColor(srgbRed: 0.878, green: 0.651, blue: 0.231, alpha: 1)
        case .boolNull: return NSColor(srgbRed: 0.239, green: 0.745, blue: 0.478, alpha: 1)
        case .punct: return NSColor(srgbRed: 0.549, green: 0.569, blue: 0.604, alpha: 1)
        case .plain: return NSColor(srgbRed: 0.788, green: 0.800, blue: 0.824, alpha: 1)
        }
    }
}
