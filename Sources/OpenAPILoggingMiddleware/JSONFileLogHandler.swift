import Foundation
import Logging

final class JSONFileLogHandler: LogHandler, @unchecked Sendable {
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

    var requestLog: [[String: Any]] = []

    private let label: String
    private let fileHandle: FileHandle
    private let logFileURL: URL
    private let logFileName: String
    private var _logLevel: Logger.Level = .info
    private let logPrefix: String

    init(label: String, logFileURL: URL, logPrefix: String = "") {
        self.label = label
        self.logFileURL = logFileURL
        self.logFileName = logFileURL.lastPathComponent
        self.logPrefix = logPrefix

        // Open or create the log file
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }

        // Print the path to the log file only once
        print("\(logPrefix)JSON log file created at path: \(logFileURL.path)")

        // File handle for writing
        self.fileHandle = try! FileHandle(forWritingTo: logFileURL)
    }

    deinit {
        self.fileHandle.closeFile() // Ensure the file is closed when done
    }

    // MARK: MetaDtata -

    // Required for LogHandler protocol
    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { return metadata[key] }
        set { metadata[key] = newValue }
    }

    var metadata: Logger.Metadata = [:]

    var logLevel: Logger.Level {
        get { self._logLevel }
        set { self._logLevel = newValue }
    }

    func log(level: Logger.Level,
             message: Logger.Message,
             metadata: Logger.Metadata?,
             source: String,
             file: String,
             function: String,
             line: UInt) {

        guard let metadata = metadata else { return }

        // Create the log entry dictionary
        var logEntry: [String: Any] = [
            LogKey.timestamp.rawValue: Date.loggableCurrentDate()
        ]

        // Process metadata and headers as before
        for (key, value) in metadata {
            if key == LogMetadataKey.requestHeadersArray.rawValue || key == LogMetadataKey.responseHeadersArray.rawValue {
                // Convert headers from array of strings to a dictionary
                let headerArrayString = value.description
                let headerDictionary = headerArrayString.convertHeaderStringToDictionary()
                let source = key == LogMetadataKey.requestHeadersArray.rawValue ? "request": "response"
                let name = "\(source) headers"
                logEntry[name] = headerDictionary
            } else if key == LogMetadataKey.requestHeadersJSON.rawValue || key == LogMetadataKey.responseHeadersJSON.rawValue {
                if let dictionary = value.description.meAsJSONStringToDictionary() {
                    let source = key == LogMetadataKey.requestHeadersJSON.rawValue ? "request": "response"
                    let name = "\(source) headers"
                    logEntry[name] = dictionary
                }
            } else {
                logEntry[key] = value.description
            }
        }

        loadExistingLogs()
        requestLog.append(logEntry)
        saveLogAsJSON()
    }
}

private extension JSONFileLogHandler {

    func saveLogAsJSON() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logFileURL = documentsPath.appendingPathComponent(logFileName)

        do {
            // Convert the `requestLog` array to JSON data
            let jsonData = try JSONSerialization.data(withJSONObject: requestLog, options: .prettyPrinted)

            // Overwrite the file by writing the JSON data
            try jsonData.write(to: logFileURL, options: .atomic)

        } catch {
            print("\(logPrefix)Error saving log: \(error)")
        }
    }

    func loadExistingLogs() {
        let logFileURL = documentsPath.appendingPathComponent(logFileName)

        if let data = try? Data(contentsOf: logFileURL),
           let existingLogs = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
            requestLog = existingLogs // Add previous logs to the in-memory array
        }
    }
}

public extension Date {
    static func loggableCurrentDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy. HH:mm:ss"
        return dateFormatter.string(from: Date())
    }
}
