import AppKit
import SwiftUI
import LogXCore

struct ContentView: View {
    @EnvironmentObject private var store: LogStore

    var body: some View {
        NavigationSplitView {
            DeviceRail()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
        } content: {
            RequestList()
                .navigationSplitViewColumnWidth(min: 420, ideal: 640, max: 900)
        } detail: {
            RequestDetail()
                .navigationSplitViewColumnWidth(min: 320, ideal: 420, max: 640)
        }
        .background(LogXTheme.bg)
        .toolbar {
            ToolbarItemGroup(placement: .principal) {
                Text(windowTitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(LogXTheme.muted)
            }
        }
        .searchable(
            text: Binding(
                get: { store.query },
                set: { store.applyQuery($0) }
            ),
            prompt: "URL, method, status…"
        )
        .background(RefreshKeyCatcher { Task { await store.refresh(full: true) } })
        .onExitCommand {
            store.selectedKey = nil
        }
    }

    private var windowTitle: String {
        let device = store.selectedScope.title
        let app = store.selectedAppId == "all"
            ? "Barcha ilovalar"
            : (store.apps.first(where: { $0.id == store.selectedAppId })?.shortLabel ?? store.selectedAppId)
        return "LogX — \(device) · \(app)"
    }
}

private struct RefreshKeyCatcher: NSViewRepresentable {
    var onRefresh: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = CatcherView()
        view.onRefresh = onRefresh
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? CatcherView)?.onRefresh = onRefresh
    }

    final class CatcherView: NSView {
        var onRefresh: (() -> Void)?
        override var acceptsFirstResponder: Bool { true }
        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers?.lowercased() == "r" {
                onRefresh?()
                return true
            }
            return super.performKeyEquivalent(with: event)
        }
    }
}
