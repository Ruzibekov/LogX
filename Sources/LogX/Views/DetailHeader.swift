import AppKit
import SwiftUI
import LogXCore

struct DetailHeader: View {
    @EnvironmentObject private var store: LogStore
    var log: NetworkLog
    var tab: DetailTab
    var copied: Bool
    var onCopy: () -> Void
    var onShare: () -> Void
    @State private var urlCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(log.method)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(LogXTheme.methodColor(log.method))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(LogXTheme.methodColor(log.method).opacity(0.18))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(LogXTheme.methodColor(log.method).opacity(0.35), lineWidth: 1)
                    )

                HStack(spacing: 5) {
                    Circle()
                        .fill(LogXTheme.status(log.statusClass))
                        .frame(width: 6, height: 6)
                    Text(log.responseCode.map(String.init) ?? "NET")
                        .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(LogXTheme.status(log.statusClass))
                    Text(log.statusDescription)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LogXTheme.status(log.statusClass).opacity(0.95))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(LogXTheme.status(log.statusClass).opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(LogXTheme.status(log.statusClass).opacity(0.3), lineWidth: 1)
                )

                if let ms = log.durationMs {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9.5))
                        Text(ms >= 1000 ? String(format: "%.2f s", Double(ms) / 1000) : "\(ms) ms")
                    }
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(LogXTheme.muted)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(LogXTheme.well, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(LogXTheme.line, lineWidth: 1))
                }

                Text(bodySizeLabel(log))
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(LogXTheme.muted)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(LogXTheme.well, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(LogXTheme.line, lineWidth: 1))

                Spacer()

                HeaderIconButton(icon: copied ? "checkmark" : "doc.on.doc", isHighlighted: copied, help: "Nusxa", action: onCopy)
                HeaderIconButton(
                    icon: store.favoriteKeys.contains(log.key) ? "star.fill" : "star",
                    isHighlighted: store.favoriteKeys.contains(log.key),
                    highlightColor: LogXTheme.warn,
                    help: "Sevimli"
                ) {
                    store.toggleFavorite(log.key)
                }
                HeaderIconButton(icon: "square.and.arrow.up", help: "Rasm ulashish", action: onShare)
            }

            HStack(spacing: 8) {
                Text(log.url.isEmpty ? log.api : log.url)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(LogXTheme.text2)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Spacer(minLength: 4)

                Button {
                    CopyBox.plainText(log.url.isEmpty ? log.api : log.url)
                    urlCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { urlCopied = false }
                } label: {
                    Image(systemName: urlCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundStyle(urlCopied ? LogXTheme.ok : LogXTheme.muted2)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help("URL nusxalash")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LogXTheme.well)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(LogXTheme.line, lineWidth: 1)
                    )
            )

            HStack(spacing: 6) {
                metaChip("Ilova", log.appLabel)
                metaChip("Qurilma", log.fieldDeviceLabel)
                if let env = log.environment, !env.isEmpty {
                    metaChip("Muhit", [env, log.flavor, log.appVersion].compactMap { $0 }.joined(separator: " · "))
                }
                if let feature = log.feature, !feature.isEmpty {
                    metaChip("Modul", log.moduleName ?? feature)
                }
            }

            let pinfl = log.userInfoPinfl ?? log.assistantJshshir
            let sid = log.sessionId
            let did = log.requestHeaders["device-id"]
            if (pinfl != nil && !pinfl!.isEmpty) || (sid != nil && !sid!.isEmpty) || (did != nil && !did!.isEmpty) {
                HStack(spacing: 6) {
                    if let pinfl, !pinfl.isEmpty { metaChip("PINFL", pinfl) }
                    if let sid, !sid.isEmpty { metaChip("Sessiya", sid) }
                    if let did, !did.isEmpty { metaChip("device-id", did) }
                }
            }

            if let msg = log.responseBodyMessage ?? log.responseMessage, !msg.isEmpty {
                HStack(spacing: 7) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(msg)
                        .font(.system(size: 11.5, weight: .medium))
                }
                .foregroundStyle(LogXTheme.warn)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(LogXTheme.warn.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(LogXTheme.warn.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
        .padding(12)
        .background(LogXTheme.panel)
    }

    private func metaChip(_ k: String, _ v: String) -> some View {
        Button {
            CopyBox.plainText(v)
        } label: {
            HStack(spacing: 4) {
                Text(k)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(LogXTheme.muted2)
                Text(v)
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(LogXTheme.text2)
                    .lineLimit(1)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(LogXTheme.well, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(LogXTheme.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help("Nusxalash")
    }

    private func bodySizeLabel(_ log: NetworkLog) -> String {
        let raw: String
        switch tab {
        case .request: raw = log.requestBody ?? ""
        case .response: raw = log.responseBody ?? ""
        case .headers: raw = JSONFormat.headersText(request: log.requestHeaders, response: log.responseHeaders)
        case .params: raw = JSONFormat.body(for: log, tab: .params)
        }
        let bytes = raw.utf8.count
        if bytes >= 1024 * 1024 { return String(format: "%.1f MB", Double(bytes) / 1_048_576) }
        if bytes >= 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return "\(bytes) B"
    }
}

private struct HeaderIconButton: View {
    var icon: String
    var isHighlighted: Bool = false
    var highlightColor: Color = LogXTheme.ok
    var help: String
    var action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(isHighlighted ? highlightColor : (hovered ? LogXTheme.text : LogXTheme.muted))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(hovered ? LogXTheme.panel2 : LogXTheme.well)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isHighlighted ? highlightColor.opacity(0.5) : (hovered ? LogXTheme.accent.opacity(0.4) : LogXTheme.line), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(help)
    }
}
