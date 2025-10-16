import OpenAPIRuntime
import Foundation
import HTTPTypes
import Logging

public actor LoggingMiddleware {

    // MARK: Properties -

    private let logger: Logger
    public let bodyLoggingPolicy: BodyLoggingPolicy
    public let logPrefix: String
    public let appName: String?
    private let logFileName: String
    private let jsonLogFileName: String

    // MARK: init -

    public init(logger: Logger? = nil,
                bodyLoggingConfiguration: BodyLoggingPolicy = .upTo(maxBytes: 1024 * 1024 * 2),
                appName: String? = nil,
                logPrefix: String = "") {
        self.logPrefix = logPrefix
        self.appName = appName

        // Generate file names based on appName and logPrefix
        let cleanAppName = appName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { $0.isASCII && ($0.isLetter || $0.isNumber) }

        let cleanPrefix = logPrefix
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .filter { $0.isASCII && ($0.isLetter || $0.isNumber) }

        // Build file prefix: appName_logPrefix or fallback to one of them or default
        let filePrefix: String
        if let appName = cleanAppName, !appName.isEmpty {
            if !cleanPrefix.isEmpty {
                filePrefix = "\(appName)_\(cleanPrefix)"
            } else {
                filePrefix = appName
            }
        } else if !cleanPrefix.isEmpty {
            filePrefix = cleanPrefix
        } else {
            filePrefix = "OpenAPILog"
        }

        self.logFileName = "_\(filePrefix).log"
        self.jsonLogFileName = "_\(filePrefix).json"

        if let logger = logger {
            self.logger = logger
        } else {
            self.logger = Self.defaultLogger(
                logPrefix: logPrefix,
                jsonLogFileName: self.jsonLogFileName
            )
        }
        self.bodyLoggingPolicy = bodyLoggingConfiguration
    }

    // MARK: File Handling -

    private static func createStreamLogHandler(label: String, logPrefix: String) -> StreamLogHandler {
        return StreamLogHandler(label: label, logPrefix: logPrefix)
    }

    private static func createJSONFileLogHandler(label: String, logPrefix: String, jsonLogFileName: String) -> JSONFileLogHandler {
        let docPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logFileURL = docPath.appendingPathComponent(jsonLogFileName)
        return JSONFileLogHandler(label: label, logFileURL: logFileURL, logPrefix: logPrefix)
    }

    // MARK: Default Logger -

    private static func defaultLogger(logPrefix: String, jsonLogFileName: String) -> Logger {
        let label = "com.openapi.logger"

        // Set up the logger with a multiplex log handler that includes both file and stream handlers
        var logger = Logger(label: label, factory: { _ in
            MultiplexLogHandler(handlers: [
                createStreamLogHandler(label: label, logPrefix: logPrefix),
                createJSONFileLogHandler(label: label, logPrefix: logPrefix, jsonLogFileName: jsonLogFileName)
            ])
        })
        logger.logLevel = .debug // Set the desired log level
        return logger
    }
}

// MARK: Client -

extension LoggingMiddleware: ClientMiddleware {
    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let (requestBodyToLog, requestBodyForNext) = try await bodyLoggingPolicy.process(body)

        log(request, requestBodyToLog, operationID, baseURL)

        do {
            let (response, responseBody) = try await next(request, requestBodyForNext, baseURL)
            let (responseBodyToLog, responseBodyForNext) = try await bodyLoggingPolicy.process(responseBody)

            log(request, response, responseBodyToLog, operationID, response.status.code, response.status.reasonPhrase)
            return (response, responseBodyForNext)
        } catch {

            log(request, failedWith: error, operationID: operationID)

            throw error
        }
    }
}

// MARK: Server -

extension LoggingMiddleware: ServerMiddleware {
    public func intercept(
        _ request: HTTPTypes.HTTPRequest,
        body: OpenAPIRuntime.HTTPBody?,
        metadata: OpenAPIRuntime.ServerRequestMetadata,
        operationID: String,
        next: @Sendable (HTTPTypes.HTTPRequest, OpenAPIRuntime.HTTPBody?, OpenAPIRuntime.ServerRequestMetadata)
            async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?)
    ) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?) {

        let (requestBodyToLog, requestBodyForNext) = try await bodyLoggingPolicy.process(body)
        log(request, requestBodyToLog, operationID)
        do {
            let (response, responseBody) = try await next(request, requestBodyForNext, metadata)
            let (responseBodyToLog, responseBodyForNext) = try await bodyLoggingPolicy.process(responseBody)
            log(request, response, responseBodyToLog, operationID, response.status.code, response.status.reasonPhrase)
            return (response, responseBodyForNext)
        } catch {
            log(request, failedWith: error, operationID: operationID)
            throw error
        }
    }
}


// MARK: Logging -

extension LoggingMiddleware {
    func log(_ request: HTTPRequest,
             _ requestBody: BodyLoggingPolicy.BodyLog,
             _ operationID: String,
             _ baseURL: URL? = nil) {
        let fullURL = baseURL?.appendingPathComponent(request.path ?? "")
        let headersString = request.headerFields.toJSONString() ?? ""

        var metadata: Logger.Metadata = [
            LogMetadataKey.method.rawValue: .stringConvertible(request.method),
            LogMetadataKey.path.rawValue: .stringConvertible(request.path ?? "<nil>"),
            LogMetadataKey.baseURL.rawValue: .stringConvertible(baseURL?.absoluteString ?? "<nil>"),
            LogMetadataKey.fullPath.rawValue: .stringConvertible(fullURL?.absoluteString ?? "<nil>"),
            LogMetadataKey.requestHeadersJSON.rawValue: .stringConvertible(headersString),
            LogMetadataKey.requestBody.rawValue: .stringConvertible(requestBody),
            LogMetadataKey.operationID.rawValue: .stringConvertible(operationID)
        ]

        // Ensure unique keys in metadata
        metadata[LogMetadataKey.uniqueKey.rawValue] = .stringConvertible(UUID().uuidString) // Example for a unique key
        logger.debug("Request", metadata: metadata)
    }

    func log(_ request: HTTPRequest,
             _ response: HTTPResponse,
             _ responseBody: BodyLoggingPolicy.BodyLog,
             _ operationID: String,
             _ statusCode: Int,
             _ statusReason: String,
             _ baseURL: URL? = nil) {
        let fullURL = baseURL?.appendingPathComponent(request.path ?? "")
        let headersString = request.headerFields.toJSONString() ?? ""

        // Cache the response JSON for potential decoding errors

        var metadata: Logger.Metadata = [
            LogMetadataKey.method.rawValue: .stringConvertible(request.method),
            LogMetadataKey.path.rawValue: .stringConvertible(request.path ?? "<nil>"),
            LogMetadataKey.baseURL.rawValue: .stringConvertible(baseURL?.absoluteString ?? "<nil>"),
            LogMetadataKey.fullPath.rawValue: .stringConvertible(fullURL?.absoluteString ?? "<nil>"),
            LogMetadataKey.responseHeadersJSON.rawValue: .stringConvertible(headersString),
            LogMetadataKey.responseBody.rawValue: .stringConvertible(responseBody),
            LogMetadataKey.operationID.rawValue: .stringConvertible(operationID),
            LogMetadataKey.statusCode.rawValue: .stringConvertible(statusCode),
            LogMetadataKey.statusReason.rawValue: .stringConvertible(statusReason)
        ]

        // Ensure unique keys in metadata
        metadata[LogMetadataKey.uniqueKey.rawValue] = .stringConvertible(UUID().uuidString) // Example for a unique key
        logger.debug("Response", metadata: metadata)
    }

    func log(_ request: HTTPRequest, failedWith error: any Error, operationID: String) {

        var metadata: Logger.Metadata = [
            LogMetadataKey.method.rawValue: .stringConvertible(request.method),
            LogMetadataKey.path.rawValue: .stringConvertible(request.path ?? "<nil>"),
            LogMetadataKey.error.rawValue: .string(error.localizedDescription),
            LogMetadataKey.operationID.rawValue: .stringConvertible(operationID)
        ]
        // Ensure unique keys in metadata
        metadata[LogMetadataKey.uniqueKey.rawValue] = .stringConvertible(UUID().uuidString) // Example for a unique key
        logger.debug("Request error", metadata: metadata)
    }
}
