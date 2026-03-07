import Foundation

actor OpenService {
    private let runner = ShellCommandRunner()
    
    private func openPath() -> String {
        return "/usr/bin/open"
    }
    
    private func runOpenCommand(_ arguments: [String], timeout: TimeInterval = 120) async throws -> String {
        let path = openPath()
        
        print("[Heimdall:open] Running: \(path) \(arguments.joined(separator: " "))")
        
        return try await runner.execute(
            command: path,
            arguments: arguments,
            environment: nil,
            timeout: timeout
        )
    }
    
    func openSimulator(udid: String) async throws {
        _ = try await runOpenCommand([
            "-a", "Simulator",
                    "--args",
                    "-CurrentDeviceUDID", udid])
    }
    
}
