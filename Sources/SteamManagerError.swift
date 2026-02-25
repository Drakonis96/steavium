import Foundation

enum SteamManagerError: LocalizedError {
    case missingScript(String)
    case homebrewNotFound
    case preflightBlocking([RuntimePreflightCheckKind])
    case wineRuntimeNotFound
    case dataWipeSelectionRequired
    case steamAlreadyRunning
    case gameProfileGameNotFound(appID: Int)
    case gameProfileExecutableNotFound(appID: Int)
    case gameProfileSteamRootNotFound
    case gameProfileLocalConfigUnreadable(path: String)
    case gameProfileLocalConfigWriteFailed(path: String)
    case gameProfileCompatibilityVerificationFailed(executable: String, expected: String, actual: String?)

    func errorDescription(in language: AppLanguage) -> String {
        switch self {
        case .missingScript(let name):
            return L.errorMissingScript(name).resolve(in: language)
        case .homebrewNotFound:
            return L.errorHomebrewNotFound.resolve(in: language)
        case .preflightBlocking(let failingChecks):
            let checksText = failingChecks
                .map { $0.title(in: language) }
                .joined(separator: ", ")
            return L.errorPreflightBlocking(checksText).resolve(in: language)
        case .wineRuntimeNotFound:
            return L.errorWineRuntimeNotFound.resolve(in: language)
        case .dataWipeSelectionRequired:
            return L.errorDataWipeSelectionRequired.resolve(in: language)
        case .steamAlreadyRunning:
            return L.errorSteamAlreadyRunning.resolve(in: language)
        case .gameProfileGameNotFound(let appID):
            return L.errorGameNotFound(appID).resolve(in: language)
        case .gameProfileExecutableNotFound(let appID):
            return L.errorExecutableNotFound(appID).resolve(in: language)
        case .gameProfileSteamRootNotFound:
            return L.errorSteamRootNotFound.resolve(in: language)
        case .gameProfileLocalConfigUnreadable(let path):
            return L.errorLocalConfigUnreadable(path).resolve(in: language)
        case .gameProfileLocalConfigWriteFailed(let path):
            return L.errorLocalConfigWriteFailed(path).resolve(in: language)
        case .gameProfileCompatibilityVerificationFailed(let executable, let expected, let actual):
            let expectedText = expected.isEmpty ? "none" : expected
            let actualText: String
            if let actual, !actual.isEmpty {
                actualText = actual
            } else {
                actualText = "none"
            }
            return L.errorCompatVerificationFailed(executable, expectedText, actualText).resolve(in: language)
        }
    }

    var errorDescription: String? {
        errorDescription(in: .english)
    }
}
