import Foundation

struct ShellResult: Sendable {
    let command: String
    let output: String
}

enum ShellError: LocalizedError, Sendable {
    case launchFailed(command: String, underlyingMessage: String)
    case exitedNonZero(command: String, status: Int32, output: String)

    var errorDescription: String? {
        switch self {
        case .launchFailed(let command, let message):
            return "Failed to launch command (\(command)): \(message)"
        case .exitedNonZero(let command, let status, let output):
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "Command failed (\(command)) with exit code \(status)."
            }
            return "Command failed (\(command)) with exit code \(status):\n\(trimmed)"
        }
    }
}

enum ShellRunner {
    static func run(
        executable: String,
        arguments: [String],
        environment: [String: String] = [:],
        currentDirectory: URL? = nil
    ) throws -> ShellResult {
        let commandText = ([executable] + arguments).joined(separator: " ")

        let outputFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("steavium-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: outputFileURL.path, contents: nil)

        let outputHandle = try FileHandle(forWritingTo: outputFileURL)
        defer {
            try? outputHandle.close()
            try? FileManager.default.removeItem(at: outputFileURL)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory
        process.standardOutput = outputHandle
        process.standardError = outputHandle

        var mergedEnvironment = ProcessInfo.processInfo.environment
        for (key, value) in environment {
            mergedEnvironment[key] = value
        }
        process.environment = mergedEnvironment

        do {
            try process.run()
        } catch {
            throw ShellError.launchFailed(command: commandText, underlyingMessage: error.localizedDescription)
        }

        process.waitUntilExit()
        try outputHandle.synchronize()

        let outputData = (try? Data(contentsOf: outputFileURL)) ?? Data()
        let output = String(decoding: outputData, as: UTF8.self)

        if process.terminationStatus != 0 {
            throw ShellError.exitedNonZero(
                command: commandText,
                status: process.terminationStatus,
                output: output
            )
        }

        return ShellResult(command: commandText, output: output)
    }

    /// Async wrapper that runs the shell command on a background thread,
    /// freeing the caller's executor (e.g. an actor) during execution.
    static func runAsync(
        executable: String,
        arguments: [String],
        environment: [String: String] = [:],
        currentDirectory: URL? = nil
    ) async throws -> ShellResult {
        try await Task.detached(priority: .userInitiated) {
            try ShellRunner.run(
                executable: executable,
                arguments: arguments,
                environment: environment,
                currentDirectory: currentDirectory
            )
        }.value
    }
}
