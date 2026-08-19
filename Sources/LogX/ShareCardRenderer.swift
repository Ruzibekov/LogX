import AppKit
import LogXCore

enum ShareCardRenderer {
    static func image(log: NetworkLog, tab: DetailTab) -> NSImage {
        let body = JSONFormat.body(for: log, tab: tab)
        let spans = tab == .headers ? [JSONSpan(body, .plain)] : JSONFormat.highlight(body.isEmpty ? "—" : body)
        let caption = ShareCardRenderer.header(log)
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
                .foregroundColor: NSColor(srgbRed: 0.64, green: 0.60, blue: 0.55, alpha: 1),
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
        NSColor(srgbRed: 0.078, green: 0.071, blue: 0.063, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        NSColor(srgbRed: 0.878, green: 0.478, blue: 0.239, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 4, height: size.height)).fill()

        let title = NSAttributedString(string: caption.title, attributes: [
            .font: titleFont,
            .foregroundColor: NSColor(srgbRed: 0.96, green: 0.94, blue: 0.91, alpha: 1),
        ])
        title.draw(at: NSPoint(x: pad, y: size.height - 40))

        let meta = NSAttributedString(string: caption.meta, attributes: [
            .font: small,
            .foregroundColor: NSColor(srgbRed: 0.64, green: 0.60, blue: 0.55, alpha: 1),
        ])
        meta.draw(in: NSRect(x: pad, y: size.height - 78, width: width - pad * 2, height: 32))

        let tabTitle = NSAttributedString(string: tab.title.uppercased(), attributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor(srgbRed: 0.878, green: 0.478, blue: 0.239, alpha: 1),
            .kern: 1.1,
        ])
        tabTitle.draw(at: NSPoint(x: pad, y: size.height - 104))

        attrBody.draw(with: NSRect(
            x: pad,
            y: 36,
            width: width - pad * 2,
            height: size.height - 148
        ), options: [.usesLineFragmentOrigin, .usesFontLeading])

        let brand = NSAttributedString(string: "LogX", attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor(srgbRed: 0.64, green: 0.60, blue: 0.55, alpha: 1),
        ])
        brand.draw(at: NSPoint(x: pad, y: 14))
        image.unlockFocus()
        return image
    }

    static func pngData(log: NetworkLog, tab: DetailTab) -> Data? {
        let img = image(log: log, tab: tab)
        guard let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff)
        else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    private struct Header {
        var title: String
        var meta: String
    }

    private static func header(_ log: NetworkLog) -> Header {
        let code = log.responseCode.map(String.init) ?? "NET"
        let url = log.url.isEmpty ? log.api : log.url
        let app = log.appShortLabel == AppProfile.unknown.shortLabel ? "" : log.appShortLabel
        return Header(
            title: "\(log.method)  \(code)",
            meta: [url, app, log.device ?? log.deviceModel ?? ""].filter { !$0.isEmpty }.joined(separator: "  ·  ")
        )
    }

    private static func color(_ kind: JSONSpanKind) -> NSColor {
        switch kind {
        case .key: return NSColor(srgbRed: 0.49, green: 0.91, blue: 0.53, alpha: 1)
        case .string: return NSColor(srgbRed: 0.65, green: 0.84, blue: 1.0, alpha: 1)
        case .number: return NSColor(srgbRed: 0.47, green: 0.75, blue: 1.0, alpha: 1)
        case .boolNull: return NSColor(srgbRed: 1.0, green: 0.48, blue: 0.45, alpha: 1)
        case .punct: return NSColor(srgbRed: 0.55, green: 0.58, blue: 0.62, alpha: 1)
        case .plain: return NSColor(srgbRed: 0.90, green: 0.88, blue: 0.84, alpha: 1)
        }
    }
}
