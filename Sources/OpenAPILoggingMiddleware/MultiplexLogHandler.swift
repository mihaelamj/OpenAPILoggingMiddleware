import Foundation
import Logging

/// A log handler that forwards log messages to multiple other log handlers.
final class MultiplexLogHandler: LogHandler, @unchecked Sendable {
    private var logHandlers: [LogHandler]

    /// Initialize with multiple log handlers.
    /// - Parameter handlers: The log handlers to multiplex log messages to.
    init(handlers: [LogHandler]) {
        self.logHandlers = handlers
    }

    var logLevel: Logger.Level {
        get { logHandlers.first?.logLevel ?? .info }
        set {
            for var handler in logHandlers {
                handler.logLevel = newValue
            }
        }
    }

    var metadata: Logger.Metadata {
        get { logHandlers.first?.metadata ?? [:] }
        set {
            for var handler in logHandlers {
                handler.metadata = newValue
            }
        }
    }

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { return logHandlers.first?[metadataKey: key] }
        set {
            for var handler in logHandlers {
                handler[metadataKey: key] = newValue
            }
        }
    }

    func log(level: Logger.Level,
             message: Logger.Message,
             metadata: Logger.Metadata?,
             source: String,
             file: String,
             function: String,
             line: UInt) {

        for handler in logHandlers {
            handler.log(level: level,
                        message: message,
                        metadata: metadata,
                        source: source,
                        file: file,
                        function: function,
                        line: line)
        }
    }
}
