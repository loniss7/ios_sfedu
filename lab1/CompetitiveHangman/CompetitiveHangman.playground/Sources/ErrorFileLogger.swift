import Foundation

/// Appends runtime and self-check failures beside the playground page so Git can track them.
public enum ErrorFileLogger {
    private static let fileName = "runtime-errors.log"

    public static func record(_ error: Error, sourceFile: String) {
        record(message: String(describing: error), sourceFile: sourceFile)
    }

    public static func record(message: String, sourceFile: String) {
        let pageURL = URL(fileURLWithPath: sourceFile).standardizedFileURL
        let logURL = pageURL
            .deletingLastPathComponent()
            .appendingPathComponent(fileName, isDirectory: false)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] \(message)\n"
        let data = Data(entry.utf8)

        do {
            if FileManager.default.fileExists(atPath: logURL.path) {
                let file = try FileHandle(forWritingTo: logURL)
                defer { try? file.close() }
                _ = try file.seekToEnd()
                try file.write(contentsOf: data)
            } else {
                try data.write(to: logURL, options: .atomic)
            }
            print("Error log saved to: \(logURL.path)")
        } catch {
            print("Could not write error log to \(logURL.path): \(error)")
        }
    }
}
