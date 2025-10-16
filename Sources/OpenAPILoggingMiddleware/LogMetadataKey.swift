import Foundation

enum LogMetadataKey: String {
    case method
    case path
    case fullPath
    case baseURL
    case responseHeadersArray
    case responseHeadersJSON
    case requestHeadersArray
    case requestHeadersJSON
    case requestBody
    case responseBody
    case operationID
    case statusCode
    case statusReason
    case error
    case uniqueKey
}

enum LogKey: String {
    case metadata
    case timestamp
}
