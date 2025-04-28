import Foundation

class ImageGenerationService {
    static let shared = ImageGenerationService()
    
    private init() {}
    
    func generateImages(
        imageData: Data?,
        userID: String,
        userDescription: String,
        numThemes: Int
    ) async throws -> [String: Any] {
        // Clear any previous API response data
        APIResponseStore.shared.clearAll()
        print("Cleared previous API response data")
        
        // Call the backend API to create the image
        let result = try await NetworkService.shared.uploadToCreateAPI(
            imageData: imageData,
            userID: userID,
            userDescription: userDescription,
            numThemes: numThemes
        )
        
        print("Successfully processed API/create: \(result)")
        
        // Process the API response format
        if let requestID = result["request_id"] as? String,
           let sourceImageID = result["source_image_id"] as? String,
           let imagesArray = result["images"] as? [[String: Any]] {
            
            let themeImages = imagesArray.compactMap { imageDict -> ThemeImage? in
                guard let resultImageID = imageDict["result_image_id"] as? String,
                      let themeID = imageDict["theme_id"] as? String,
                      let themeName = imageDict["theme_name"] as? String else {
                    return nil
                }
                
                return ThemeImage(resultImageID: resultImageID, themeID: themeID, themeName: themeName)
            }
            
            let apiResponse = APIResponse(
                requestID: requestID,
                sourceImageID: sourceImageID,
                images: themeImages
            )
            
            // Save using the APIResponseStore with additional data
            APIResponseStore.shared.saveResponse(
                apiResponse,
                userDescription: userDescription,
                sourceImageData: imageData
            )
            print("Stored API response with \(themeImages.count) theme images")
            
            return result
        }
        
        throw NSError(domain: "ImageGenerationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid API response format"])
    }
} 