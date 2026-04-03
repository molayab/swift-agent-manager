import Foundation

enum GitRunner {
    @discardableResult
    static func run(_ args: String...) -> (output: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + args
        process.currentDirectoryURL = repoRoot

        let pipe    = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError  = errPipe

        try? process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let out  = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (out, process.terminationStatus)
    }
}
