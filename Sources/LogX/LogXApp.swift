import AppKit
import SwiftUI
import LogXCore

enum LogXLog {
    /// Shu hajmdan oshsa fayl qayta boshlanadi — cheksiz o'sish yo'q.
    static let maxBytes: UInt64 = 2_000_000

    static func write(_ message: String) {
        let line = "\(Date()) \(message)\n"
        let url = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Logs/LogX.log")
        guard let data = line.data(using: .utf8) else { return }
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64) ?? 0
        if size == 0 || size > maxBytes {
            try? data.write(to: url)
            return
        }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        }
    }
}

@main
enum LogXMain {
    @MainActor static var delegate: LogXAppDelegate?

    @MainActor static func main() {
        LogXLog.write("main start")
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = LogXAppDelegate()
        LogXMain.delegate = delegate
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class LogXAppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation, NSWindowDelegate {
    private var window: NSWindow?
    private var store: LogStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        LogXLog.write("didFinishLaunching")
        setupMainMenu()
        let store = LogStore()
        self.store = store
        applyAppearance(AppearancePreference.load())
        let root = ContentView()
            .environmentObject(store)
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
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.delegate = self
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

    /// ⌘W oynani yashiradi, jonli oqim ishlashda davom etadi; Dock'dan qaytariladi.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showWindow(nil) }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
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
        add(appMenu, "\(appName)ni yashirish", #selector(NSApplication.hide(_:)), "h", .command)
        add(appMenu, "Boshqalarni yashirish", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option])
        appMenu.addItem(withTitle: "Barchasini ko'rsatish", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        add(appMenu, "\(appName)dan chiqish", #selector(NSApplication.terminate(_:)), "q", .command)

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "Fayl")
        fileMenuItem.submenu = fileMenu
        add(fileMenu, "Ko'rinadiganlarni HAR saqlash…", #selector(exportHAR(_:)), "s", .command, target: self)
        add(fileMenu, "Ko'rinadiganlarni JSON saqlash…", #selector(exportJSON(_:)), "s", [.command, .shift], target: self)
        fileMenu.addItem(NSMenuItem.separator())
        add(fileMenu, "Yopish", #selector(NSWindow.performClose(_:)), "w", .command)

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Tahrirlash")
        editMenuItem.submenu = editMenu
        add(editMenu, "Bekor qilish", Selector(("undo:")), "z", .command)
        add(editMenu, "Qaytarish", Selector(("redo:")), "z", [.command, .shift])
        editMenu.addItem(NSMenuItem.separator())
        add(editMenu, "Kesib olish", #selector(NSText.cut(_:)), "x", .command)
        add(editMenu, "Nusxalash", #selector(NSText.copy(_:)), "c", .command)
        add(editMenu, "Qo'yish", #selector(NSText.paste(_:)), "v", .command)
        add(editMenu, "Barchasini tanlash", #selector(NSText.selectAll(_:)), "a", .command)
        editMenu.addItem(NSMenuItem.separator())
        add(editMenu, "cURL sifatida nusxalash", #selector(copyCurl(_:)), "c", [.command, .shift], target: self)
        add(editMenu, "Tanani nusxalash", #selector(copyBody(_:)), "c", [.command, .option], target: self)
        editMenu.addItem(NSMenuItem.separator())
        let findItem = NSMenuItem(title: "Topish", action: nil, keyEquivalent: "")
        let findMenu = NSMenu(title: "Topish")
        findItem.submenu = findMenu
        editMenu.addItem(findItem)
        add(findMenu, "JSON ichida topish", #selector(focusDetailFind(_:)), "f", .command, target: self)
        add(findMenu, "So'rovlarni qidirish", #selector(focusListSearch(_:)), "f", [.command, .shift], target: self)
        add(findMenu, "Tana ichida topish", #selector(focusDetailFind(_:)), "f", [.command, .option], target: self)

        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "Ko'rinish")
        viewMenuItem.submenu = viewMenu
        add(viewMenu, "Yon panel", #selector(NSSplitViewController.toggleSidebar(_:)), "s", [.command, .control])
        add(viewMenu, "Tokenlarni yashirish", #selector(toggleRedact(_:)), "t", [.command, .shift], target: self)
        viewMenu.addItem(NSMenuItem.separator())
        let themeItem = NSMenuItem(title: "Mavzu", action: nil, keyEquivalent: "")
        let themeMenu = NSMenu(title: "Mavzu")
        themeItem.submenu = themeMenu
        viewMenu.addItem(themeItem)
        for option in AppearancePreference.allCases {
            let item = NSMenuItem(title: option.title, action: #selector(selectAppearance(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = option.rawValue
            themeMenu.addItem(item)
        }
        viewMenu.addItem(NSMenuItem.separator())
        add(viewMenu, "Kattalashtirish", #selector(zoomIn(_:)), "=", .command, target: self)
        add(viewMenu, "Kichiklashtirish", #selector(zoomOut(_:)), "-", .command, target: self)
        add(viewMenu, "Asl o'lcham", #selector(zoomReset(_:)), "0", .command, target: self)
        viewMenu.addItem(NSMenuItem.separator())
        add(viewMenu, "To'liq ekran", #selector(NSWindow.toggleFullScreen(_:)), "f", [.command, .control])

        let sessionMenuItem = NSMenuItem()
        mainMenu.addItem(sessionMenuItem)
        let sessionMenu = NSMenu(title: "Sessiya")
        sessionMenuItem.submenu = sessionMenu
        add(sessionMenu, "Pauza", #selector(togglePause(_:)), "p", .command, target: self)
        add(sessionMenu, "Ro'yxatni tozalash", #selector(clearLogs(_:)), "k", .command, target: self)
        add(sessionMenu, "Tozalashni bekor qilish", #selector(undoClear(_:)), "k", [.command, .option], target: self)
        sessionMenu.addItem(NSMenuItem.separator())
        add(sessionMenu, "Qayta ulash", #selector(reconnect(_:)), "r", .command, target: self)
        sessionMenu.addItem(NSMenuItem.separator())
        add(sessionMenu, "Keyingi xato", #selector(nextError(_:)), "e", .command, target: self)
        add(sessionMenu, "Oldingi xato", #selector(previousError(_:)), "e", [.command, .shift], target: self)
        sessionMenu.addItem(NSMenuItem.separator())
        add(sessionMenu, "Qayta yuborish", #selector(replaySelected(_:)), "\r", .command, target: self)
        add(sessionMenu, "Solishtirish uchun belgilash (A)", #selector(toggleDiffAnchor(_:)), "d", .command, target: self)
        add(sessionMenu, "A bilan solishtirish", #selector(compareWithAnchor(_:)), "d", [.command, .shift], target: self)
        add(sessionMenu, "Oldingi bir xil so'rov bilan solishtirish", #selector(compareWithPrevious(_:)), "d", [.command, .option], target: self)
        sessionMenu.addItem(NSMenuItem.separator())
        add(sessionMenu, "Kuzat", #selector(toggleFollow(_:)), "l", .command, target: self)
        add(sessionMenu, "Shovqinni yashirish", #selector(toggleHideNoise(_:)), "n", [.command, .option], target: self)

        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Oyna")
        windowMenuItem.submenu = windowMenu
        add(windowMenu, "Kichraytirish", #selector(NSWindow.performMiniaturize(_:)), "m", .command)
        windowMenu.addItem(withTitle: "Kattalashtirish", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(NSMenuItem.separator())
        add(windowMenu, "LogX oynasi", #selector(showWindow(_:)), "1", [.command, .option], target: self)
        windowMenu.addItem(withTitle: "Hammasini oldinga", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }

    @discardableResult
    private func add(
        _ menu: NSMenu,
        _ title: String,
        _ action: Selector,
        _ key: String,
        _ mods: NSEvent.ModifierFlags,
        target: AnyObject? = nil
    ) -> NSMenuItem {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = mods
        item.target = target
        return item
    }

    @objc func showWindow(_ sender: Any?) {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func togglePause(_ sender: Any?) { store?.togglePause() }
    @objc func clearLogs(_ sender: Any?) { store?.clearLogs() }
    @objc func undoClear(_ sender: Any?) { store?.undoClear() }
    @objc func copyBody(_ sender: Any?) { store?.copySelectedBody() }
    @objc func toggleRedact(_ sender: Any?) { store?.redactEnabled.toggle() }
    @objc func toggleFollow(_ sender: Any?) { store?.toggleFollowLatest() }
    @objc func nextError(_ sender: Any?) { store?.moveToError(forward: true) }
    @objc func previousError(_ sender: Any?) { store?.moveToError(forward: false) }
    @objc func toggleHideNoise(_ sender: Any?) { store?.toggleHideNoise() }
    @objc func replaySelected(_ sender: Any?) { store?.replaySelected() }
    @objc func toggleDiffAnchor(_ sender: Any?) { store?.toggleDiffAnchorSelected() }
    @objc func compareWithAnchor(_ sender: Any?) { store?.compareSelectedWithAnchor() }
    @objc func compareWithPrevious(_ sender: Any?) { store?.compareSelectedWithPrevious() }
    @objc func exportHAR(_ sender: Any?) { store?.exportHAR() }
    @objc func exportJSON(_ sender: Any?) { store?.exportJSON() }

    @objc func selectAppearance(_ sender: Any?) {
        guard let raw = (sender as? NSMenuItem)?.representedObject as? String,
              let option = AppearancePreference(rawValue: raw) else { return }
        option.save()
        applyAppearance(option)
    }

    private func applyAppearance(_ option: AppearancePreference) {
        switch option {
        case .system: NSApp.appearance = nil
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        }
    }

    @objc func focusListSearch(_ sender: Any?) {
        showWindow(nil)
        NotificationCenter.default.post(name: LogXNotice.focusListSearch, object: nil)
    }

    @objc func focusDetailFind(_ sender: Any?) {
        showWindow(nil)
        if store?.selectedLog != nil {
            NotificationCenter.default.post(name: LogXNotice.focusDetailFind, object: nil)
        } else {
            focusListSearch(sender)
        }
    }

    @objc func zoomIn(_ sender: Any?) {
        NotificationCenter.default.post(name: LogXNotice.zoomIn, object: nil)
    }

    @objc func zoomOut(_ sender: Any?) {
        NotificationCenter.default.post(name: LogXNotice.zoomOut, object: nil)
    }

    @objc func zoomReset(_ sender: Any?) {
        NotificationCenter.default.post(name: LogXNotice.zoomReset, object: nil)
    }

    @objc func reconnect(_ sender: Any?) {
        guard let store else { return }
        Task { await store.start() }
    }

    @objc func copyCurl(_ sender: Any?) {
        guard let store, let log = store.selectedLog else { return }
        store.copy(CurlBuilder.command(for: log, redact: store.redactEnabled), what: "cURL")
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let store else { return true }
        switch menuItem.action {
        case #selector(togglePause(_:)):
            menuItem.title = store.isPaused ? "Davom ettirish" : "Pauza"
        case #selector(copyCurl(_:)), #selector(copyBody(_:)):
            return store.selectedLog != nil
        case #selector(focusDetailFind(_:)):
            if menuItem.keyEquivalentModifierMask == .command {
                menuItem.title = store.selectedLog != nil ? "JSON ichida topish" : "So'rovlarni qidirish"
                return true
            }
            return store.selectedLog != nil
        case #selector(replaySelected(_:)):
            return store.selectedLog.map { store.canReplay($0) } ?? false
        case #selector(toggleDiffAnchor(_:)):
            menuItem.title = store.selectedLog != nil && store.diffAnchorKey == store.selectedKey
                ? "A belgisini olib tashlash" : "Solishtirish uchun belgilash (A)"
            return store.selectedLog != nil
        case #selector(compareWithAnchor(_:)):
            return store.canCompareWithAnchor
        case #selector(compareWithPrevious(_:)):
            return store.canCompareSelectedWithPrevious
        case #selector(exportHAR(_:)), #selector(exportJSON(_:)):
            return store.canExport
        case #selector(nextError(_:)), #selector(previousError(_:)):
            return store.errorCount > 0
        case #selector(clearLogs(_:)):
            return store.logCount > 0
        case #selector(undoClear(_:)):
            return store.canUndoClear
        case #selector(selectAppearance(_:)):
            let raw = menuItem.representedObject as? String
            menuItem.state = raw == AppearancePreference.load().rawValue ? .on : .off
        case #selector(toggleRedact(_:)):
            menuItem.state = store.redactEnabled ? .on : .off
        case #selector(toggleFollow(_:)):
            menuItem.state = store.followLatest ? .on : .off
        case #selector(toggleHideNoise(_:)):
            menuItem.state = store.hideNoise ? .on : .off
        default:
            break
        }
        return true
    }
}
