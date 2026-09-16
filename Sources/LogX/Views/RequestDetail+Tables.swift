import SwiftUI
import LogXCore

extension RequestDetail {
    @ViewBuilder
    func paramsTable(_ params: [(key: String, value: String)]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(params.enumerated()), id: \.offset) { idx, pair in
                ParamRowView(key: pair.key, value: pair.value, isEven: idx % 2 == 0)
                if idx < params.count - 1 {
                    Divider().overlay(LogXTheme.divider)
                }
            }
        }
    }

    @ViewBuilder
    func headersTable(_ log: NetworkLog) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !log.responseHeaders.isEmpty {
                headerSection(title: "Javob sarlavhalari", headers: log.responseHeaders)
            }
            if !log.requestHeaders.isEmpty {
                headerSection(title: "So'rov sarlavhalari", headers: log.requestHeaders)
            }
            if log.responseHeaders.isEmpty && log.requestHeaders.isEmpty {
                Text("Sarlavhalar yo'q")
                    .font(LogXType.ui(LogXType.body))
                    .foregroundStyle(LogXTheme.muted)
                    .padding(16)
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    func headerSection(title: String, headers: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(LogXTheme.text)
                Text("\(headers.count)")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(LogXTheme.muted2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(LogXTheme.well))
                Spacer()
                Button {
                    let text = headers.sorted(by: { $0.key < $1.key }).map { "\($0.key): \($0.value)" }.joined(separator: "\n")
                    store.copy(text, what: title)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9))
                        Text("Nusxa")
                            .font(LogXType.ui(LogXType.caption))
                    }
                    .foregroundStyle(LogXTheme.muted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(LogXTheme.panel2.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .padding(.bottom, 4)

            let sorted = headers.sorted(by: { $0.key.localizedStandardCompare($1.key) == .orderedAscending })
            ForEach(Array(sorted.enumerated()), id: \.offset) { idx, pair in
                ParamRowView(key: pair.key, value: pair.value, isEven: idx % 2 == 0)
                if idx < sorted.count - 1 {
                    Divider().overlay(LogXTheme.divider)
                }
            }
        }
    }
}
