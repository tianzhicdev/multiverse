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

// Additional structure to store generation inputs
struct GenerationInputs: Codable {
    let userDescription: String
    let imageDataExists: Bool
    let timestamp: Date
    let album: String
    
    init(userDescription: String, hasImageData: Bool, album: String = "default") {
        self.userDescription = userDescription
        self.imageDataExists = hasImageData
        self.timestamp = Date()
        self.album = album
    }
}

// Helper class to store and retrieve API response from UserDefaults
class APIResponseStore {
    static let shared = APIResponseStore()
    private let userDefaults = UserDefaults.standard
    private let responseKey = "lastAPIResponse"
    private let historyKey = "apiResponseHistory"
    private let inputsKey = "lastGenerationInputs"
    private let sourceImageKey = "lastSourceImage"
    
    // Save the API response along with generation inputs
    func saveResponse(_ response: APIResponse, userDescription: String, sourceImageData: Data?, album: String = "default") {
        // Save the response
        if let encoded = try? JSONEncoder().encode(response) {
            userDefaults.set(encoded, forKey: responseKey)
            
            // Also save to history
            var history = getResponseHistory()
            history.append(response)
            if let historyEncoded = try? JSONEncoder().encode(history) {
                userDefaults.set(historyEncoded, forKey: historyKey)
            }
        }
        
        // Save the generation inputs
        let inputs = GenerationInputs(userDescription: userDescription, hasImageData: sourceImageData != nil, album: album)
        if let encoded = try? JSONEncoder().encode(inputs) {
            userDefaults.set(encoded, forKey: inputsKey)
        }
        
        // Save the source image data if provided
        if let imageData = sourceImageData {
            userDefaults.set(imageData, forKey: sourceImageKey)
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
    
    func getLastGenerationInputs() -> GenerationInputs? {
        guard let data = userDefaults.data(forKey: inputsKey) else { return nil }
        return try? JSONDecoder().decode(GenerationInputs.self, from: data)
    }
    
    func getLastSourceImage() -> Data? {
        return userDefaults.data(forKey: sourceImageKey)
    }
    
    func clearLastResponse() {
        userDefaults.removeObject(forKey: responseKey)
    }
    
    func clearAll() {
        userDefaults.removeObject(forKey: responseKey)
        userDefaults.removeObject(forKey: inputsKey)
        userDefaults.removeObject(forKey: sourceImageKey)
    }
} 