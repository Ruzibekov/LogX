import AppKit
import SwiftUI

/// Trackpad pinch (magnification) detektori — SwiftUI daraxti ustida
/// ikki barmoqli chimchilash (pinch-to-zoom) va smart zoom'ni boshqaradi.
struct PinchDetector: NSViewRepresentable {
    var zoom: CGFloat
    var onZoomChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(zoom: zoom, onZoomChange: onZoomChange)
    }

    func makeNSView(context: Context) -> PinchHostView {
        let view = PinchHostView()
        let recognizer = NSMagnificationGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleMagnify(_:))
        )
        view.addGestureRecognizer(recognizer)
        view.onSmartMagnify = { [weak coordinator = context.coordinator] in
            coordinator?.handleSmartMagnify()
        }
        return view
    }

    func updateNSView(_ nsView: PinchHostView, context: Context) {
        context.coordinator.zoom = zoom
        context.coordinator.onZoomChange = onZoomChange
    }

    final class Coordinator: NSObject {
        var zoom: CGFloat
        var onZoomChange: (CGFloat) -> Void
        private var baseZoom: CGFloat = 1.0

        init(zoom: CGFloat, onZoomChange: @escaping (CGFloat) -> Void) {
            self.zoom = zoom
            self.onZoomChange = onZoomChange
            self.baseZoom = zoom
        }

        @objc func handleMagnify(_ recognizer: NSMagnificationGestureRecognizer) {
            switch recognizer.state {
            case .began:
                baseZoom = zoom
            case .changed:
                let next = min(max(baseZoom * (1.0 + recognizer.magnification), 0.5), 4.0)
                DispatchQueue.main.async {
                    self.onZoomChange(next)
                }
            case .ended, .cancelled:
                let next = min(max(baseZoom * (1.0 + recognizer.magnification), 0.5), 4.0)
                baseZoom = next
                DispatchQueue.main.async {
                    self.onZoomChange(next)
                }
            default:
                break
            }
        }

        func handleSmartMagnify() {
            let next: CGFloat = abs(zoom - 1.0) < 0.08 ? 1.5 : 1.0
            DispatchQueue.main.async {
                self.onZoomChange(next)
            }
        }
    }
}

final class PinchHostView: NSView {
    var onSmartMagnify: (() -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func smartMagnify(with event: NSEvent) {
        onSmartMagnify?()
    }
}
