import Foundation

public enum MonitorClientError: Error, Equatable, CustomStringConvertible {
    case serverDown
    case http(Int)
    case decode
    case noDevice
    case idle(Int)

    public var description: String {
        switch self {
        case .serverDown: return "Monitor server ishlamayapti (8787)"
        case .http(let code): return "HTTP \(code)"
        case .decode: return "Javob o‘qilmadi"
        case .noDevice: return "Ulangan device yo‘q"
        case .idle(let seconds): return "Stream \(seconds) s jim — qayta ulanmoqda"
        }
    }
}

public struct MonitorClient: Sendable {
    public var baseURL: URL

    public init(baseURL: URL = URL(string: "http://127.0.0.1:8787")!) {
        self.baseURL = baseURL
    }

    public func ping() async -> Bool {
        guard let url = URL(string: "/api/devices", relativeTo: baseURL) else { return false }
        var req = URLRequest(url: url)
        req.timeoutInterval = 2
        req.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (_, res) = try await MonitorSessions.rest.data(for: req)
            return (res as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    public func devices() async throws -> [ConnectedDevice] {
        try await deviceState().devices
    }

    public func deviceState() async throws -> DevicesPayload {
        try await get("/api/devices")
    }

    public func reclaimAdb() async throws -> DevicesPayload {
        try await send("/api/adb/reclaim", method: "POST")
    }

    public func apps() async throws -> [AppProfile] {
        do {
            let payload: AppsPayload = try await get("/api/apps")
            return payload.apps.isEmpty ? AppProfile.builtIn : payload.apps
        } catch {
            return AppProfile.builtIn
        }
    }

    public func ensureServer(projectRoot: URL) async -> Bool {
        if await ping() { return true }
        let script = projectRoot.appendingPathComponent("tools/rsid-http-monitor/service.sh")
        guard FileManager.default.isExecutableFile(atPath: script.path)
            || FileManager.default.fileExists(atPath: script.path)
        else { return false }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path, "start"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try await runToExit(process)
        } catch {
            return false
        }
        for _ in 0..<12 {
            try? await Task.sleep(nanoseconds: 250_000_000)
            if await ping() { return true }
        }
        return await ping()
    }

    public static func projectRoot() -> URL {
        if let env = ProcessInfo.processInfo.environment["LOGX_MONITOR_ROOT"], !env.isEmpty {
            return URL(fileURLWithPath: env)
        }
        if let env = ProcessInfo.processInfo.environment["LOGX_PROJECT_ROOT"], !env.isEmpty {
            return URL(fileURLWithPath: env)
        }
        var url = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        for _ in 0..<10 {
            let marker = url.appendingPathComponent("tools/rsid-http-monitor/server.mjs")
            if FileManager.default.fileExists(atPath: marker.path) { return url }
            url.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Projects/online-mahalla")
    }

    /// Jarayon tugashini kooperativ ipni band qilmasdan kutadi.
    private func runToExit(_ process: Process) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { _ in cont.resume() }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                cont.resume(throwing: error)
            }
        }
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        try await send(path, method: "GET")
    }

    private func send<T: Decodable>(_ path: String, method: String) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw MonitorClientError.decode }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 12
        req.cachePolicy = .reloadIgnoringLocalCacheData
        let data: Data
        let res: URLResponse
        do {
            (data, res) = try await MonitorSessions.rest.data(for: req)
        } catch {
            throw MonitorClientError.serverDown
        }
        let code = (res as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw MonitorClientError.http(code) }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw MonitorClientError.decode
        }
    }
}
