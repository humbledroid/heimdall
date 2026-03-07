import Foundation

// MARK: - Shell Command Runner

/// Thread-safe utility for executing shell commands and capturing output.
actor ShellCommandRunner {

    enum CommandError: LocalizedError {
        case commandNotFound(String)
        case executionFailed(exitCode: Int32, stderr: String)
        case outputDecodingFailed
        case timeout

        var errorDescription: String? {
            switch self {
            case .commandNotFound(let cmd):
                return "Command not found: \(cmd)"
            case .executionFailed(let code, let stderr):
                return "Command failed (exit \(code)): \(stderr)"
            case .outputDecodingFailed:
                return "Failed to decode command output"
            case .timeout:
                return "Command timed out"
            }
        }
    }

    /// Shared environment with PATH set up for typical macOS developer tools.
    private static let sharedEnvironment: [String: String] = {
        var env = ProcessInfo.processInfo.environment
        // Ensure common tool paths are in PATH
        let extraPaths = [
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
        ]
        let existingPath = env["PATH"] ?? "/usr/bin:/bin"
        let combined = (extraPaths + existingPath.components(separatedBy: ":"))
            .removingDuplicates()
            .joined(separator: ":")
        env["PATH"] = combined
        return env
    }()

    // MARK: - Execute

    /// Execute a command and return its stdout as a string.
    ///
    /// IMPORTANT: Reads stdout/stderr concurrently on background threads while
    /// the process runs, to avoid pipe buffer deadlocks. (macOS pipe buffers
    /// are ~64KB; if the process writes more than that to stdout before we read,
    /// it blocks forever waiting for the buffer to drain.)
    func execute(
        command: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        currentDirectory: String? = nil,
        timeout: TimeInterval = 30
    ) async throws -> String {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Start with shared env, then overlay custom env
        var processEnv = Self.sharedEnvironment
        if let env = environment {
            for (key, value) in env {
                processEnv[key] = value
            }
        }
        process.environment = processEnv

        if let dir = currentDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: dir)
        }

        print("[Heimdall:Shell] Running: \(command) \(arguments.joined(separator: " "))")

        return try await withCheckedThrowingContinuation { continuation in
            // Collect stdout and stderr on background threads to prevent
            // pipe buffer deadlock. readDataToEndOfFile() blocks until EOF,
            // so it MUST run on a separate thread — not in the termination handler.
            var stdoutData = Data()
            var stderrData = Data()
            let readGroup = DispatchGroup()

            readGroup.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                readGroup.leave()
            }

            readGroup.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                readGroup.leave()
            }

            do {
                try process.run()
            } catch {
                print("[Heimdall:Shell] Failed to launch: \(command) — \(error)")
                // Close pipes so the reader threads finish
                stdoutPipe.fileHandleForReading.closeFile()
                stderrPipe.fileHandleForReading.closeFile()
                continuation.resume(throwing: CommandError.commandNotFound(command))
                return
            }

            // Track whether we killed it via timeout
            var timedOut = false

            // Set up timeout
            let timer = DispatchSource.makeTimerSource()
            timer.schedule(deadline: .now() + timeout)
            timer.setEventHandler {
                if process.isRunning {
                    timedOut = true
                    print("[Heimdall:Shell] TIMEOUT after \(timeout)s — killing process")
                    process.terminate()
                }
            }
            timer.resume()

            process.terminationHandler = { _ in
                timer.cancel()

                // Wait for the reader threads to finish collecting all output
                readGroup.wait()

                if timedOut {
                    print("[Heimdall:Shell] Process was killed due to timeout")
                    continuation.resume(throwing: CommandError.timeout)
                    return
                }

                guard let output = String(data: stdoutData, encoding: .utf8) else {
                    continuation.resume(throwing: CommandError.outputDecodingFailed)
                    return
                }

                if process.terminationStatus != 0 {
                    let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                    print("[Heimdall:Shell] Command failed (\(process.terminationStatus)): \(stderr)")
                    continuation.resume(
                        throwing: CommandError.executionFailed(
                            exitCode: process.terminationStatus,
                            stderr: stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    )
                    return
                }

                print("[Heimdall:Shell] Command succeeded, output: \(stdoutData.count) bytes")
                continuation.resume(returning: output)
            }
        }
    }

    // MARK: - Execute with Shell

    /// Execute a command through /bin/sh (useful for commands that need PATH resolution).
    func executeShell(
        _ command: String,
        environment: [String: String]? = nil,
        timeout: TimeInterval = 30
    ) async throws -> String {
        try await execute(
            command: "/bin/sh",
            arguments: ["-c", command],
            environment: environment,
            timeout: timeout
        )
    }

    // MARK: - Execute with Login Shell

    /// Execute a command through a login shell (/bin/zsh -l -c).
    /// This loads the user's full shell profile (~/.zprofile, ~/.zshrc),
    /// which is critical for commands like `xcrun simctl` that need the
    /// full Xcode/developer environment set up properly.
    func executeLoginShell(
        _ command: String,
        environment: [String: String]? = nil,
        timeout: TimeInterval = 60
    ) async throws -> String {
        try await execute(
            command: "/bin/zsh",
            arguments: ["-l", "-c", command],
            environment: environment,
            timeout: timeout
        )
    }

    // MARK: - Execute JSON

    /// Execute a command and decode its JSON stdout into a Decodable type.
    func executeJSON<T: Decodable>(
        command: String,
        arguments: [String] = [],
        environment: [String: String]? = nil
    ) async throws -> T {
        let output = try await execute(
            command: command,
            arguments: arguments,
            environment: environment
        )

        guard let data = output.data(using: .utf8) else {
            throw CommandError.outputDecodingFailed
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Launch Detached

    /// Launch a long-running process without waiting for it to finish.
    @discardableResult
    func launchDetached(
        command: String,
        arguments: [String] = [],
        environment: [String: String]? = nil
    ) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments

        var processEnv = Self.sharedEnvironment
        if let env = environment {
            for (key, value) in env {
                processEnv[key] = value
            }
        }
        process.environment = processEnv

        // Suppress output for detached processes
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        print("[Heimdall:Shell] Launching detached: \(command) \(arguments.joined(separator: " "))")
        try process.run()
        return process
    }

    // MARK: - Which

    /// Find the full path of a command using `which`.
    func which(_ command: String) async -> String? {
        do {
            let output = try await execute(
                command: "/usr/bin/which",
                arguments: [command]
            )
            let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return path.isEmpty ? nil : path
        } catch {
            return nil
        }
    }
}

// MARK: - Array Extension

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
