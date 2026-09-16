import AppKit
import Foundation
import SwiftUI

/// Ulashish PNG'lari alohida papkada turadi va bir soatdan eskilari o'chiriladi.
enum ShareScratch {
    static let maxAge: TimeInterval = 3600

    static func directory() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("LogX-share", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func purgeStale(in dir: URL, now: Date = Date()) {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        for item in items where item.pathExtension == "png" {
            let modified = (try? item.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? now
            if now.timeIntervalSince(modified) > maxAge {
                try? fm.removeItem(at: item)
            }
        }
    }
}

struct SharePickerAnchor: NSViewRepresentable {
    @ObservedObject var host: SharePickerHost

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        host.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        host.view = nsView
    }
}
