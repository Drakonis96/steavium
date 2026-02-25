import Foundation

enum RuntimePreflightCheckKind: String, CaseIterable, Codable, Sendable {
    case homebrew
    case diskSpace
    case network
    case ffmpeg
    case runtime

    var isBlocking: Bool {
        switch self {
        case .homebrew, .diskSpace, .network:
            return true
        case .ffmpeg, .runtime:
            return false
        }
    }

    func title(in language: AppLanguage) -> String {
        switch self {
        case .homebrew:
            return L.homebrewTitle.resolve(in: language)
        case .diskSpace:
            return L.diskSpaceTitle.resolve(in: language)
        case .network:
            return L.networkTitle.resolve(in: language)
        case .ffmpeg:
            return "ffmpeg"
        case .runtime:
            return L.wineRuntimeTitle.resolve(in: language)
        }
    }
}

enum RuntimePreflightStatus: String, Codable, Sendable {
    case ok
    case warning
    case failed

    func title(in language: AppLanguage) -> String {
        switch self {
        case .ok:
            return L.statusOK.resolve(in: language)
        case .warning:
            return L.statusWarning.resolve(in: language)
        case .failed:
            return L.statusFailed.resolve(in: language)
        }
    }
}

struct RuntimePreflightCheck: Identifiable, Codable, Sendable {
    let kind: RuntimePreflightCheckKind
    let status: RuntimePreflightStatus
    let detailEnglish: String
    let detailSpanish: String

    var id: RuntimePreflightCheckKind { kind }

    func detail(in language: AppLanguage) -> String {
        language.pick(detailEnglish, detailSpanish)
    }
}

struct RuntimePreflightReport: Codable, Sendable {
    let generatedAt: Date
    let checks: [RuntimePreflightCheck]

    static let empty = RuntimePreflightReport(
        generatedAt: .distantPast,
        checks: []
    )

    var overallStatus: RuntimePreflightStatus {
        if checks.isEmpty {
            return .warning
        }
        if checks.contains(where: { $0.status == .failed }) {
            return .failed
        }
        if checks.contains(where: { $0.status == .warning }) {
            return .warning
        }
        return .ok
    }

    var blockingFailureKinds: [RuntimePreflightCheckKind] {
        checks
            .filter { $0.status == .failed && $0.kind.isBlocking }
            .map(\.kind)
    }

    var hasBlockingFailures: Bool {
        !blockingFailureKinds.isEmpty
    }

    func check(for kind: RuntimePreflightCheckKind) -> RuntimePreflightCheck? {
        checks.first(where: { $0.kind == kind })
    }
}
