import AppKit
import SwiftUI
import LogXCore

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

final class LogXAppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var window: NSWindow?
    private var store: LogStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        LogXLog.write("didFinishLaunching")
        setupMainMenu()
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
        window.minSize = NSSize(width: 960, height: 640)
        window.isReleasedWhenClosed = false
        if !window.setFrameUsingName("LogX.Main") {
            window.setContentSize(NSSize(width: 1440, height: 900))
            window.center()
        }
        window.setFrameAutosaveName("LogX.Main")
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        LogXLog.write("window shown \(window.frame.debugDescription)")
        Task { await store.start() }
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        let appName = "LogX"
        appMenu.addItem(withTitle: "\(appName) haqida", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())

        let hideItem = appMenu.addItem(withTitle: "\(appName)ni yashirish", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        hideItem.keyEquivalentModifierMask = .command

        let hideOthersItem = appMenu.addItem(withTitle: "Boshqalarni yashirish", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]

        appMenu.addItem(withTitle: "Barchasini ko'rsatish", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())

        let quitItem = appMenu.addItem(withTitle: "\(appName)dan chiqish", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = .command

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Tahrirlash")
        editMenuItem.submenu = editMenu

        editMenu.addItem(withTitle: "Kesib olish", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Nusxalash", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Qo'yish", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Barchasini tanlash", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(NSMenuItem.separator())
        let curlItem = editMenu.addItem(withTitle: "cURL sifatida nusxalash", action: #selector(copyCurl(_:)), keyEquivalent: "c")
        curlItem.target = self
        curlItem.keyEquivalentModifierMask = [.command, .shift]

        let sessionMenuItem = NSMenuItem()
        mainMenu.addItem(sessionMenuItem)
        let sessionMenu = NSMenu(title: "Sessiya")
        sessionMenuItem.submenu = sessionMenu

        let pauseItem = sessionMenu.addItem(withTitle: "Pauza", action: #selector(togglePause(_:)), keyEquivalent: "p")
        pauseItem.target = self
        pauseItem.keyEquivalentModifierMask = .command

        let clearItem = sessionMenu.addItem(withTitle: "Ro'yxatni tozalash", action: #selector(clearLogs(_:)), keyEquivalent: "k")
        clearItem.target = self
        clearItem.keyEquivalentModifierMask = .command

        sessionMenu.addItem(NSMenuItem.separator())

        let reconnectItem = sessionMenu.addItem(withTitle: "Qayta ulash", action: #selector(reconnect(_:)), keyEquivalent: "r")
        reconnectItem.target = self
        reconnectItem.keyEquivalentModifierMask = .command

        sessionMenu.addItem(NSMenuItem.separator())

        let followItem = sessionMenu.addItem(withTitle: "Kuzat", action: #selector(toggleFollow(_:)), keyEquivalent: "")
        followItem.target = self

        let noiseItem = sessionMenu.addItem(withTitle: "Shovqinni yashirish", action: #selector(toggleHideNoise(_:)), keyEquivalent: "")
        noiseItem.target = self

        sessionMenu.addItem(NSMenuItem.separator())

        let harItem = sessionMenu.addItem(withTitle: "HAR saqlash", action: #selector(exportHAR(_:)), keyEquivalent: "e")
        harItem.target = self
        harItem.keyEquivalentModifierMask = .command

        let jsonItem = sessionMenu.addItem(withTitle: "JSON saqlash", action: #selector(exportJSON(_:)), keyEquivalent: "")
        jsonItem.target = self

        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Oyna")
        windowMenuItem.submenu = windowMenu

        windowMenu.addItem(withTitle: "Yopish", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Kichraytirish", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")

        NSApp.mainMenu = mainMenu
    }

    @objc func togglePause(_ sender: Any?) {
        MainActor.assumeIsolated { store?.togglePause() }
    }

    @objc func clearLogs(_ sender: Any?) {
        MainActor.assumeIsolated { store?.clearLogs() }
    }

    @objc func reconnect(_ sender: Any?) {
        guard let store else { return }
        Task { await store.start() }
    }

    @objc func copyCurl(_ sender: Any?) {
        MainActor.assumeIsolated {
            guard let log = store?.selectedLog else { return }
            CopyBox.plainText(CurlBuilder.command(for: log, redact: store?.redactEnabled ?? false))
        }
    }

    @objc func toggleFollow(_ sender: Any?) {
        MainActor.assumeIsolated { store?.toggleFollowLatest() }
    }

    @objc func toggleHideNoise(_ sender: Any?) {
        MainActor.assumeIsolated { store?.toggleHideNoise() }
    }

    @objc func exportHAR(_ sender: Any?) {
        MainActor.assumeIsolated { store?.exportHAR() }
    }

    @objc func exportJSON(_ sender: Any?) {
        MainActor.assumeIsolated { store?.exportJSON() }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(togglePause(_:)) {
            let paused = MainActor.assumeIsolated { store?.isPaused == true }
            menuItem.title = paused ? "Davom ettirish" : "Pauza"
        }
        if menuItem.action == #selector(copyCurl(_:)) {
            return MainActor.assumeIsolated { store?.selectedLog != nil }
        }
        if menuItem.action == #selector(toggleFollow(_:)) {
            let on = MainActor.assumeIsolated { store?.followLatest == true }
            menuItem.state = on ? .on : .off
        }
        if menuItem.action == #selector(toggleHideNoise(_:)) {
            let on = MainActor.assumeIsolated { store?.hideNoise == true }
            menuItem.state = on ? .on : .off
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
