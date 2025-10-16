import Foundation

extension String {

    func convertHeaderStringToDictionary() -> [AnyHashable: Any] {
        // Step 1: Remove the square brackets from the string
        let trimmedHeaderString = self.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))

        // Step 2: Split the string by ", " to get individual key-value pairs
        let headerArray = trimmedHeaderString.components(separatedBy: "\", \"")

        // Step 3: Create a dictionary to hold the converted key-value pairs
        var headersDictionary = [AnyHashable: Any]()

        // Step 4: Loop over the array and split each key-value pair by "="
        for header in headerArray {
            let headerComponents = header.split(separator: "=")
            if headerComponents.count == 2 {
                // Step 5: Clean up the key and value by removing any extra quotes
                let key = String(headerComponents[0]).trimmingCharacters(in: .init(charactersIn: "\""))
                let value = String(headerComponents[1]).trimmingCharacters(in: .init(charactersIn: "\""))

                // Step 6: Add the key-value pair to the dictionary
                headersDictionary[key] = value
            }
        }

        return headersDictionary
    }

    static func convertDictionaryToJSONString(_ headers: [String: String]) -> String? {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: headers, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("Error converting headers to JSON: \(error)")
            return nil
        }
    }

    /// Converts a JSON string into a dictionary.
    ///
    /// - Parameter jsonString: The JSON string to convert.
    /// - Returns: An optional dictionary if conversion is successful, otherwise `nil`.
    public func meAsJSONStringToDictionary() -> [String: Any]? {
        // Attempt to convert the JSON string into a dictionary
        guard let data = self.data(using: .utf8),
              let jsonDictionary = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return nil
        }

        return jsonDictionary
    }
}
