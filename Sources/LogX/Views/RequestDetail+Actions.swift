import SwiftUI
import LogXCore

extension RequestDetail {
    func copyPill(log: NetworkLog) -> some View {
        ActionPillButton(
            title: copied ? "Nusxalandi" : "Nusxa",
            shortcut: [.symbol("option"), .symbol("command"), .letter("C")],
            isPrimary: true,
            help: "Tanani nusxalash (⌥⌘C)"
        ) {
            copy(JSONFormat.body(for: log, tab: tab, redact: store.redactEnabled, pretty: prettyBody))
        }
    }

    func curlPill(log: NetworkLog) -> some View {
        ActionPillButton(
            title: "cURL",
            shortcut: [.symbol("command"), .symbol("shift"), .letter("C")],
            help: "cURL buyrug'ini nusxalash (⌘⇧C)"
        ) {
            store.copy(CurlBuilder.command(for: log, redact: store.redactEnabled), what: "cURL")
        }
        .keyboardShortcut("c", modifiers: [.command, .shift])
    }

    func editReplayPill(log: NetworkLog) -> some View {
        ActionPillButton(
            title: "Tahrirlash",
            icon: "square.and.pencil",
            help: "So'rovni tahrirlash va qayta yuborish (Replay Composer)"
        ) {
            store.openReplayComposer(log)
        }
        .disabled(!store.canReplay(log))
    }

    func sharePill(log: NetworkLog) -> some View {
        ActionPillButton(title: "", icon: "square.and.arrow.up", help: "Rasm sifatida ulashish", label: "Ulashish") {
            share(log)
        }
    }

    func copy(_ text: String) {
        store.copy(text, what: tab.title)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
    }

    func share(_ log: NetworkLog) {
        guard let data = ShareCardRenderer.pngData(log: log, tab: tab, redact: store.redactEnabled) else {
            store.presentError(title: "Rasm tayyorlanmadi", message: "Ulashish kartasi render bo'lmadi.")
            return
        }
        let dir = ShareScratch.directory()
        ShareScratch.purgeStale(in: dir)
        let url = dir.appendingPathComponent("logx-\(tab.rawValue)-\(Int(Date().timeIntervalSince1970)).png")
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            store.presentError(title: "Rasm saqlanmadi", message: error.localizedDescription)
            return
        }
        shareHost.present(url: url)
    }
}
