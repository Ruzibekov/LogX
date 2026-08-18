import AppKit
import SwiftUI

enum LogXLog {
    static func write(_ message: String) {
        let line = "\(Date()) \(message)\n"
        let url = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Logs/LogX.log")
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path) {
                if let handle = try? FileHandle(forWritingTo: url) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: url)
            }
        }
    }
}

@main
enum LogXMain {
    static var delegate: LogXAppDelegate?

    static func main() {
        LogXLog.write("main start")
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = LogXAppDelegate()
        LogXMain.delegate = delegate
        app.delegate = delegate
        app.run()
    }
}

final class LogXAppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var store: LogStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        LogXLog.write("didFinishLaunching")
        let store = MainActor.assumeIsolated { LogStore() }
        self.store = store
        let root = ContentView()
            .environmentObject(store)
            .preferredColorScheme(.dark)
        let hosting = NSHostingController(rootView: root)
        hosting.view.frame = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "LogX"
        window.contentViewController = hosting
        window.minSize = NSSize(width: 1100, height: 680)
        window.setContentSize(NSSize(width: 1440, height: 900))
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        LogXLog.write("window shown \(window.frame.debugDescription)")
        Task { await store.start() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
