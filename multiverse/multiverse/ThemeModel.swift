import Foundation

// Structure representing a single image with its theme information
struct ThemeImage: Codable, Identifiable {
    let resultImageID: String
    let themeID: String
    let themeName: String
    
    var id: String { resultImageID }
    
    // For decoding from JSON with snake_case keys
    enum CodingKeys: String, CodingKey {
        case resultImageID = "result_image_id"
        case themeID = "theme_id"
        case themeName = "theme_name"
    }
}

// Structure representing the full API response
struct APIResponse: Codable {
    let requestID: String
    let sourceImageID: String
    let images: [ThemeImage]
    
    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case sourceImageID = "source_image_id"
        case images
    }
}

// Helper class to store and retrieve API response from UserDefaults
class APIResponseStore {
    static let shared = APIResponseStore()
    private let userDefaults = UserDefaults.standard
    private let responseKey = "lastAPIResponse"
    private let historyKey = "apiResponseHistory"
    
    func saveResponse(_ response: APIResponse) {
        if let encoded = try? JSONEncoder().encode(response) {
            userDefaults.set(encoded, forKey: responseKey)
            
            // Also save to history
            var history = getResponseHistory()
            history.append(response)
            if let historyEncoded = try? JSONEncoder().encode(history) {
                userDefaults.set(historyEncoded, forKey: historyKey)
            }
        }
    }
    
    func getLastResponse() -> APIResponse? {
        guard let data = userDefaults.data(forKey: responseKey) else { return nil }
        return try? JSONDecoder().decode(APIResponse.self, from: data)
    }
    
    func getResponseHistory() -> [APIResponse] {
        guard let data = userDefaults.data(forKey: historyKey) else { return [] }
        return (try? JSONDecoder().decode([APIResponse].self, from: data)) ?? []
    }
    
    func clearLastResponse() {
        userDefaults.removeObject(forKey: responseKey)
    }
} 