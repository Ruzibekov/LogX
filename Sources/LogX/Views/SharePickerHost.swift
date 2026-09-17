import AppKit
import SwiftUI

final class SharePickerHost: NSObject, ObservableObject, NSSharingServicePickerDelegate {
    weak var view: NSView? {
        didSet { flushPending() }
    }
    private var picker: NSSharingServicePicker?
    private var pendingURL: URL?

    func present(url: URL) {
        if show(url: url) { return }
        pendingURL = url
        DispatchQueue.main.async { [weak self] in
            self?.flushPending()
        }
    }

    private func flushPending() {
        guard let pendingURL else { return }
        if show(url: pendingURL) {
            self.pendingURL = nil
        }
    }

    @discardableResult
    private func show(url: URL) -> Bool {
        let attached = view.flatMap { $0.window == nil ? nil : $0 }
        let anchor = attached ?? NSApp.keyWindow?.contentView
        guard let anchor, anchor.window != nil else { return false }
        let picker = NSSharingServicePicker(items: [url])
        picker.delegate = self
        self.picker = picker
        picker.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
        return true
    }

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
        picker = nil
    }
}
