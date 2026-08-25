import Foundation

public enum AnyJSONValue: Codable, Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: AnyJSONValue])
    case array([AnyJSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let b = try? c.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? c.decode(Int.self) {
            self = .int(i)
        } else if let d = try? c.decode(Double.self) {
            self = .double(d)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else if let arr = try? c.decode([AnyJSONValue].self) {
            self = .array(arr)
        } else if let dict = try? c.decode([String: AnyJSONValue].self) {
            self = .object(dict)
        } else {
            self = .null
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .int(let i): try c.encode(i)
        case .double(let d): try c.encode(d)
        case .bool(let b): try c.encode(b)
        case .object(let obj): try c.encode(obj)
        case .array(let arr): try c.encode(arr)
        case .null: try c.encodeNil()
        }
    }

    public var rawAny: Any {
        switch self {
        case .string(let s): return s
        case .int(let i): return i
        case .double(let d): return d
        case .bool(let b): return b
        case .object(let obj): return obj.mapValues { $0.rawAny }
        case .array(let arr): return arr.map { $0.rawAny }
        case .null: return NSNull()
        }
    }
}

public struct LooseMap: Decodable, Encodable, Equatable, Sendable {
    public var values: [String: String]

    public init(_ values: [String: String] = [:]) {
        self.values = values
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let dict = try? c.decode([String: String].self) {
            values = dict
            return
        }
        if let any = try? c.decode([String: AnyJSONValue].self) {
            var result: [String: String] = [:]
            for (k, v) in any {
                switch v {
                case .string(let s): result[k] = s
                case .int(let i): result[k] = String(i)
                case .double(let d): result[k] = String(d)
                case .bool(let b): result[k] = b ? "true" : "false"
                case .null: result[k] = ""
                case .object, .array:
                    if let data = try? JSONSerialization.data(withJSONObject: v.rawAny, options: [.sortedKeys]),
                       let s = String(data: data, encoding: .utf8) {
                        result[k] = s
                    }
                }
            }
            values = result
            return
        }
        values = [:]
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(values)
    }
}

public struct LooseText: Decodable, Encodable, Equatable, Sendable {
    public var text: String?

    public init(_ text: String?) {
        self.text = text
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            text = nil
            return
        }
        if let s = try? c.decode(String.self) {
            text = s
            return
        }
        if let val = try? c.decode(AnyJSONValue.self) {
            switch val {
            case .null:
                text = nil
            case .string(let s):
                text = s
            case .bool(let b):
                text = b ? "true" : "false"
            case .int(let i):
                text = String(i)
            case .double(let d):
                text = String(d)
            case .object, .array:
                let raw = val.rawAny
                if let data = try? JSONSerialization.data(withJSONObject: raw, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
                   let str = String(data: data, encoding: .utf8) {
                    text = str
                } else if let data = try? JSONSerialization.data(withJSONObject: raw, options: [.prettyPrinted, .sortedKeys]),
                          let str = String(data: data, encoding: .utf8) {
                    text = str
                } else {
                    text = nil
                }
            }
            return
        }
        text = nil
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(text)
    }
}
