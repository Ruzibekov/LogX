import AppKit

enum MethodSwatch {
    static let tones: [MethodTone] = [.get, .post, .put, .patch, .delete]
    static let dot: CGFloat = 7
    static let gap: CGFloat = 2.5

    static func center(of index: Int) -> NSPoint {
        NSPoint(x: CGFloat(index) * (dot + gap) + dot / 2, y: dot / 2)
    }

    static let image: NSImage = {
        let width = CGFloat(tones.count) * dot + CGFloat(tones.count - 1) * gap
        let image = NSImage(size: NSSize(width: width, height: dot), flipped: false) { _ in
            for (index, tone) in tones.enumerated() {
                let origin = center(of: index)
                LogXTheme.dynamicNS(tone.hex).setFill()
                NSBezierPath(ovalIn: NSRect(x: origin.x - dot / 2, y: origin.y - dot / 2, width: dot, height: dot)).fill()
            }
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = "GET, POST, PUT, PATCH, DELETE ranglari"
        return image
    }()
}
