import Foundation
import Logging

final class StreamLogHandler: LogHandler, @unchecked Sendable {
    private let label: String
    private var _logLevel: Logger.Level = .info
    var stream: TextOutputStream
    private let logPrefix: String

    init(label: String, stream: TextOutputStream = StandardOutputStream(), logPrefix: String = "") {
        self.label = label
        self.stream = stream
        self.logPrefix = logPrefix
    }

    var logLevel: Logger.Level {
        get { _logLevel }
        set { _logLevel = newValue }
    }

    var metadata: Logger.Metadata = [:]

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { return metadata[key] }
        set { metadata[key] = newValue }
    }

    // Implement the required log method from LogHandler
    func log(level: Logger.Level,
             message: Logger.Message,
             metadata: Logger.Metadata?,
             source: String,
             file: String,
             function: String,
             line: UInt) {

        guard let metadata = metadata else { return }

        for (key, value) in metadata {

            if key == LogMetadataKey.responseHeadersArray.rawValue || key == LogMetadataKey.requestHeadersArray.rawValue {
                self.stream.write("\(logPrefix)\(key) Headers:\n")
                // Convert headers from array of strings to a dictionary
                let headerArrayString = value.description
                let headerDictionary = headerArrayString.convertHeaderStringToDictionary()

                if let headerStringDictionary = headerDictionary as? [String: String] {
                    for (headerKey, headerValue) in headerStringDictionary {
                        self.stream.write("\(logPrefix)header: `\(headerKey)` = `\(headerValue.description)`\n")
                    }
                }
            } else if key == LogMetadataKey.requestHeadersJSON.rawValue || key == LogMetadataKey.responseHeadersJSON.rawValue {
                if let dictionary = value.description.meAsJSONStringToDictionary() {
                    for (headerKey, headerValue) in dictionary {
                        self.stream.write("\(logPrefix)\(key) Header: `\(headerKey)` = `\(headerValue)`\n")
                    }
                }
            } else {
                self.stream.write("\(logPrefix)`\(key)` = `\(value.description)`\n")
            }
        }
    }
}

// Standard output stream
struct StandardOutputStream: TextOutputStream {
    func write(_ string: String) {
        fputs(string, stdout)
    }
}
