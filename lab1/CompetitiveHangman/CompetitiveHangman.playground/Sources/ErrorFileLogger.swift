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
            try append(data, to: logURL)
            print("Error log saved to: \(logURL.path)")
        } catch let primaryError {
            let fallbackDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("CompetitiveHangman", isDirectory: true)
            let fallbackURL = fallbackDirectory.appendingPathComponent(fileName, isDirectory: false)

            do {
                try FileManager.default.createDirectory(at: fallbackDirectory, withIntermediateDirectories: true)
                try append(data, to: fallbackURL)
                print("Could not write error log beside the playground: \(primaryError)")
                print("Error log saved to temporary location: \(fallbackURL.path)")
            } catch {
                print("Could not write error log to \(logURL.path): \(primaryError)")
                print("Could not write fallback error log to \(fallbackURL.path): \(error)")
            }
        }
    }

    private static func append(_ data: Data, to url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            let file = try FileHandle(forWritingTo: url)
            defer { try? file.close() }
            _ = try file.seekToEnd()
            try file.write(contentsOf: data)
        } else {
            try data.write(to: url, options: .atomic)
        }
    }
}
