import Foundation

enum ValveKeyValueError: LocalizedError {
    case expectedQuotedString(position: Int)
    case expectedValue(position: Int)
    case expectedObjectStart(position: Int)
    case unterminatedString(position: Int)
    case unexpectedToken(position: Int)

    var errorDescription: String? {
        switch self {
        case .expectedQuotedString(let position):
            return "Formato ValveKV invalido: se esperaba una cadena en posicion \(position)."
        case .expectedValue(let position):
            return "Formato ValveKV invalido: se esperaba un valor en posicion \(position)."
        case .expectedObjectStart(let position):
            return "Formato ValveKV invalido: se esperaba '{' en posicion \(position)."
        case .unterminatedString(let position):
            return "Formato ValveKV invalido: cadena sin cerrar en posicion \(position)."
        case .unexpectedToken(let position):
            return "Formato ValveKV invalido: token inesperado en posicion \(position)."
        }
    }
}

indirect enum ValveKeyValueValue: Sendable, Equatable {
    case string(String)
    case object([ValveKeyValueEntry])
}

struct ValveKeyValueEntry: Sendable, Equatable {
    var key: String
    var value: ValveKeyValueValue
}

struct ValveKeyValueDocument: Sendable, Equatable {
    var entries: [ValveKeyValueEntry]

    static func parse(_ content: String) throws -> ValveKeyValueDocument {
        var parser = ValveKeyValueParser(content: content)
        return try parser.parseDocument()
    }

    func serialized() -> String {
        ValveKeyValueSerializer.serialize(entries: entries)
    }

    func string(at path: [String]) -> String? {
        guard let value = value(at: path) else {
            return nil
        }
        if case .string(let text) = value {
            return text
        }
        return nil
    }

    func value(at path: [String]) -> ValveKeyValueValue? {
        Self.value(in: entries, path: path)
    }

    mutating func setString(_ value: String, at path: [String]) {
        guard !path.isEmpty else { return }
        Self.setString(in: &entries, path: path, value: value)
    }

    mutating func removeValue(at path: [String]) {
        guard !path.isEmpty else { return }
        _ = Self.removeValue(in: &entries, path: path)
    }

    private static func value(
        in entries: [ValveKeyValueEntry],
        path: [String]
    ) -> ValveKeyValueValue? {
        guard let head = path.first else { return nil }
        guard let entry = entries.first(where: { $0.key == head }) else { return nil }
        if path.count == 1 {
            return entry.value
        }
        guard case .object(let children) = entry.value else { return nil }
        return value(in: children, path: Array(path.dropFirst()))
    }

    private static func setString(
        in entries: inout [ValveKeyValueEntry],
        path: [String],
        value: String
    ) {
        guard let head = path.first else { return }
        if path.count == 1 {
            if let index = entries.firstIndex(where: { $0.key == head }) {
                entries[index].value = .string(value)
            } else {
                entries.append(ValveKeyValueEntry(key: head, value: .string(value)))
            }
            return
        }

        let tail = Array(path.dropFirst())
        if let index = entries.firstIndex(where: { $0.key == head }) {
            switch entries[index].value {
            case .object(var children):
                setString(in: &children, path: tail, value: value)
                entries[index].value = .object(children)
            case .string:
                var children: [ValveKeyValueEntry] = []
                setString(in: &children, path: tail, value: value)
                entries[index].value = .object(children)
            }
        } else {
            var children: [ValveKeyValueEntry] = []
            setString(in: &children, path: tail, value: value)
            entries.append(ValveKeyValueEntry(key: head, value: .object(children)))
        }
    }

    @discardableResult
    private static func removeValue(
        in entries: inout [ValveKeyValueEntry],
        path: [String]
    ) -> Bool {
        guard let head = path.first else { return false }
        guard let index = entries.firstIndex(where: { $0.key == head }) else { return false }

        if path.count == 1 {
            entries.remove(at: index)
            return true
        }

        guard case .object(var children) = entries[index].value else {
            return false
        }

        let removed = removeValue(in: &children, path: Array(path.dropFirst()))
        if removed {
            if children.isEmpty {
                entries.remove(at: index)
            } else {
                entries[index].value = .object(children)
            }
        }
        return removed
    }
}

private struct ValveKeyValueParser {
    private let scalars: [UnicodeScalar]
    private var index: Int = 0

    init(content: String) {
        self.scalars = Array(content.unicodeScalars)
    }

    mutating func parseDocument() throws -> ValveKeyValueDocument {
        skipWhitespace()
        var entries: [ValveKeyValueEntry] = []
        while !isAtEnd {
            let entry = try parseEntry()
            entries.append(entry)
            skipWhitespace()
        }
        return ValveKeyValueDocument(entries: entries)
    }

    private mutating func parseEntry() throws -> ValveKeyValueEntry {
        skipWhitespace()
        let key = try parseQuotedString()
        skipWhitespace()
        let value = try parseValue()
        return ValveKeyValueEntry(key: key, value: value)
    }

    private mutating func parseValue() throws -> ValveKeyValueValue {
        skipWhitespace()
        guard let current = currentScalar else {
            throw ValveKeyValueError.expectedValue(position: index)
        }
        if current == "\"" {
            let text = try parseQuotedString()
            return .string(text)
        }
        if current == "{" {
            let object = try parseObject()
            return .object(object)
        }
        throw ValveKeyValueError.expectedValue(position: index)
    }

    private mutating func parseObject() throws -> [ValveKeyValueEntry] {
        skipWhitespace()
        guard currentScalar == "{" else {
            throw ValveKeyValueError.expectedObjectStart(position: index)
        }
        advance()
        skipWhitespace()

        var entries: [ValveKeyValueEntry] = []
        while !isAtEnd {
            if currentScalar == "}" {
                advance()
                return entries
            }
            let entry = try parseEntry()
            entries.append(entry)
            skipWhitespace()
        }

        throw ValveKeyValueError.unexpectedToken(position: index)
    }

    private mutating func parseQuotedString() throws -> String {
        skipWhitespace()
        guard currentScalar == "\"" else {
            throw ValveKeyValueError.expectedQuotedString(position: index)
        }
        advance()

        var output = String.UnicodeScalarView()
        while !isAtEnd {
            guard let scalar = currentScalar else {
                break
            }

            if scalar == "\"" {
                advance()
                return String(output)
            }

            if scalar == "\\" {
                advance()
                guard let escaped = currentScalar else {
                    throw ValveKeyValueError.unterminatedString(position: index)
                }
                switch escaped {
                case "\"":
                    output.append("\"")
                case "\\":
                    output.append("\\")
                case "n":
                    output.append("\n")
                case "t":
                    output.append("\t")
                default:
                    output.append(escaped)
                }
                advance()
                continue
            }

            output.append(scalar)
            advance()
        }

        throw ValveKeyValueError.unterminatedString(position: index)
    }

    private mutating func skipWhitespace() {
        while !isAtEnd {
            if let current = currentScalar, current.properties.isWhitespace {
                advance()
                continue
            }

            if currentScalar == "/", peekScalar == "/" {
                while let scalar = currentScalar, scalar != "\n" {
                    advance()
                }
                continue
            }

            break
        }
    }

    private var isAtEnd: Bool {
        index >= scalars.count
    }

    private var currentScalar: UnicodeScalar? {
        guard !isAtEnd else { return nil }
        return scalars[index]
    }

    private var peekScalar: UnicodeScalar? {
        let nextIndex = index + 1
        guard nextIndex < scalars.count else { return nil }
        return scalars[nextIndex]
    }

    private mutating func advance() {
        index += 1
    }
}

private enum ValveKeyValueSerializer {
    static func serialize(entries: [ValveKeyValueEntry]) -> String {
        var output = ""
        for entry in entries {
            serialize(entry: entry, indent: 0, output: &output)
        }
        return output
    }

    private static func serialize(entry: ValveKeyValueEntry, indent: Int, output: inout String) {
        let indentation = String(repeating: "\t", count: indent)
        switch entry.value {
        case .string(let value):
            output += "\(indentation)\"\(escape(entry.key))\"\t\t\"\(escape(value))\"\n"
        case .object(let children):
            output += "\(indentation)\"\(escape(entry.key))\"\n"
            output += "\(indentation){\n"
            for child in children {
                serialize(entry: child, indent: indent + 1, output: &output)
            }
            output += "\(indentation)}\n"
        }
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
}
