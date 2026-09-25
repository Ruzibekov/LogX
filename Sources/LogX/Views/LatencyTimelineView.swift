import SwiftUI
import LogXCore

struct LatencyTimelineView: View {
    @EnvironmentObject private var store: LogStore
    @State private var shiftSteps: CGFloat = 0
    @State private var hoverX: CGFloat?

    static let height: CGFloat = 44
    static let inset = EdgeInsets(top: 3, leading: 0, bottom: 5, trailing: 0)

    var body: some View {
        let logs = Array(store.visibleLogs.prefix(LatencySummary.defaultLimit))
        let points = SignalTrace.points(logs)
        GeometryReader { geo in
            let frame = SignalFrame(size: geo.size, inset: Self.inset)
            let dx = CGFloat(SignalTrace.step(limit: LatencySummary.defaultLimit)) * geo.size.width
            ZStack(alignment: .topLeading) {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: frame.y(SignalTrace.baselineY)))
                    path.addLine(to: CGPoint(x: geo.size.width, y: frame.y(SignalTrace.baselineY)))
                }
                .stroke(LogXTheme.line, lineWidth: 1)

                SignalPolyline(points: points, frame: frame)
                    .stroke(points.isEmpty ? LogXTheme.muted2 : LogXTheme.accent, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    .offset(x: shiftSteps * dx)

                ForEach(points.filter { $0.statusClass.isFailure || $0.statusClass == .err4xx }) { point in
                    Circle()
                        .fill(point.statusClass == .err4xx ? LogXTheme.warn : LogXTheme.err)
                        .frame(width: 4, height: 4)
                        .position(frame.point(point))
                        .offset(x: shiftSteps * dx)
                }

                if let selected = points.first(where: { $0.key == store.selectedKey }) {
                    marker(frame.point(selected))
                        .offset(x: shiftSteps * dx)
                }

                if let hoverX, let near = SignalTrace.nearest(points, toX: Double(hoverX / max(geo.size.width, 1))) {
                    hoverLayer(frame: frame, point: near, height: geo.size.height)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .contentShape(Rectangle())
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let location): hoverX = location.x
                case .ended: hoverX = nil
                }
            }
            .onTapGesture(coordinateSpace: .local) { location in
                let x = Double(location.x / max(geo.size.width, 1))
                if let near = SignalTrace.nearest(points, toX: x) { store.selectKey(near.key) }
            }
        }
        .frame(height: Self.height)
        .background(LogXTheme.well)
        .overlay(alignment: .topLeading) { p95Label }
        .overlay(alignment: .bottom) { Rectangle().fill(LogXTheme.line).frame(height: 1) }
        .onChange(of: points.last?.key) { old, new in
            guard let old, let new, old != new, points.contains(where: { $0.key == old }) else { return }
            advance()
        }
        .help("Kechikish oqimi · oxirgi \(points.count) so'rov")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Kechikish chizig'i, \(points.count) so'rov")
    }

    private func advance() {
        guard let animation = LogXMotion.signalShift else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { shiftSteps = 1 }
        withAnimation(animation) { shiftSteps = 0 }
    }

    @ViewBuilder
    private var p95Label: some View {
        if let p95 = LatencySummary.p95Label(store.visibleLogs) {
            Text(p95)
                .font(LogXType.mono(9, .medium))
                .foregroundStyle(LogXTheme.muted)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(LogXTheme.well.opacity(0.85), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                .padding(.top, 4)
                .padding(.leading, 8)
                .allowsHitTesting(false)
        }
    }

    private func marker(_ at: CGPoint) -> some View {
        Circle()
            .fill(LogXTheme.accent)
            .frame(width: 6, height: 6)
            .overlay(Circle().stroke(LogXTheme.well, lineWidth: 1.5))
            .position(at)
    }

    private func hoverLayer(frame: SignalFrame, point: SignalPoint, height: CGFloat) -> some View {
        let at = frame.point(point)
        let label = Self.durationLabel(point.durationMs)
        let leading = at.x > frame.size.width - 80
        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(LogXTheme.muted2)
                .frame(width: 1, height: height)
                .position(x: at.x, y: height / 2)
            marker(at)
            Text(label)
                .font(LogXType.mono(9.5, .semibold))
                .foregroundStyle(LogXTheme.text)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(LogXTheme.panel2, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                .fixedSize()
                .position(x: leading ? at.x - 36 : at.x + 36, y: 12)
        }
        .allowsHitTesting(false)
    }

    static func durationLabel(_ ms: Double?) -> String {
        guard let ms else { return "o'lchanmagan" }
        return ms >= 1000 ? String(format: "%.2f s", ms / 1000) : "\(Int(ms)) ms"
    }
}

struct SignalFrame {
    var size: CGSize
    var inset: EdgeInsets

    func y(_ ratio: Double) -> CGFloat {
        let usable = size.height - inset.top - inset.bottom
        return inset.top + usable * (1 - CGFloat(ratio))
    }

    func x(_ ratio: Double) -> CGFloat {
        size.width * CGFloat(ratio)
    }

    func point(_ point: SignalPoint) -> CGPoint {
        CGPoint(x: x(point.x), y: y(point.y))
    }
}

struct SignalPolyline: Shape {
    var points: [SignalPoint]
    var frame: SignalFrame

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let base = frame.y(SignalTrace.baselineY)
        guard let first = points.first else {
            path.move(to: CGPoint(x: 0, y: base))
            path.addLine(to: CGPoint(x: rect.width, y: base))
            return path
        }
        path.move(to: CGPoint(x: 0, y: base))
        path.addLine(to: CGPoint(x: frame.x(first.x), y: base))
        for point in points {
            path.addLine(to: frame.point(point))
        }
        return path
    }
}
