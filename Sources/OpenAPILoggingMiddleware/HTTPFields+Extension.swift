
import Foundation
import HTTPTypes

/// Converts HTTPFields to a string, ensuring unique header names.
public extension HTTPFields {
    /// Converts HTTPFields to a string, ensuring unique header names.
    ///
    /// - Parameter headerFields: The HTTPFields collection to convert.
    /// - Returns: A string representing the header fields in `name=value` format.
    func toArrayString() -> String {
        // Use a dictionary to store unique header fields (name-value pairs)
        var uniqueHeaders: [String: String] = [:]

        // Iterate over header fields and add them to the dictionary (overwriting duplicates)
        self.forEach { field in
            uniqueHeaders[field.name.rawName] = field.value
        }

        // Convert the unique dictionary to an array of "name=value" strings
        let result = uniqueHeaders.map { "\($0.key)=\($0.value)" }

        // Join the array elements into a single string, separated by commas
        return result.joined(separator: ", ")
    }

    func toDictionary() -> [String: String] {
        let dict = self.map {
            ($0.name.rawName, $0.value.description)
        }
        let result = Dictionary(uniqueKeysWithValues: dict)
        return result
    }

    func toJSONString() -> String? {
        let dictionary = self.toDictionary()
        let headersString = String.convertDictionaryToJSONString(dictionary)
        return headersString
    }
}
