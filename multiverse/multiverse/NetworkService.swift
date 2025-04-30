import Foundation
import os.log

class NetworkService {
    private let domain = "https://multiverse.for-better.biz"
    private var userManager = UserManager.shared
    static let shared = NetworkService()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.multiverse", category: "NetworkService")
    
    // func uploadItem(imageData: Data?, text: String) async throws -> Data? {
    //     logger.info("Starting upload request with text: \(text)")
    //     logger.info("Image data present: \(imageData != nil)")
    //     if let imageData = imageData {
    //         logger.info("Image data size: \(imageData.count) bytes")
    //     }
        
    //     var request = URLRequest(url: URL(string: "\(domain)/api/gen/test")!)
    //     request.httpMethod = "POST"
        
    //     // Create multipart form data
    //     let boundary = UUID().uuidString
    //     request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    //     logger.info("Request headers: \(request.allHTTPHeaderFields ?? [:])")
        
    //     var body = Data()
        
    //     // Add text
    //     body.append("--\(boundary)\r\n".data(using: .utf8)!)
    //     body.append("Content-Disposition: form-data; name=\"user_description\"\r\n\r\n".data(using: .utf8)!)
    //     body.append(text.data(using: .utf8)!)
    //     body.append("\r\n".data(using: .utf8)!)
        
    //     // Add image if exists
    //     if let imageData = imageData {
    //         logger.info("Adding image data to request")
    //         body.append("--\(boundary)\r\n".data(using: .utf8)!)
    //         body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
    //         body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
    //         body.append(imageData)
    //         body.append("\r\n".data(using: .utf8)!)
    //     } else {
    //         logger.info("No image data provided")
    //     }
        
    //     body.append("--\(boundary)--\r\n".data(using: .utf8)!)
    //     request.httpBody = body
    //     logger.info("Request body size: \(body.count) bytes")
        
    //     do {
    //         let (data, response) = try await URLSession.shared.data(for: request)
            
    //         guard let httpResponse = response as? HTTPURLResponse else {
    //             logger.error("Invalid response type")
    //             throw NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
    //         }
            
    //         if !(200...299).contains(httpResponse.statusCode) {
    //             let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
    //             logger.error("Server returned error: \(errorMessage) (Status: \(httpResponse.statusCode))")
    //             throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
    //         }
            
    //         // Check if the response is an image
    //         if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
    //            contentType.contains("image/") {
    //             logger.info("Received image response")
    //             return data
    //         } else {
    //             logger.info("Received non-image response")
    //             return nil
    //         }
    //     } catch {
    //         logger.error("Network request failed: \(error.localizedDescription)")
    //         throw error
    //     }
    // }
    
    func uploadToCreateAPI(imageData: Data?, userID: String, userDescription: String, numThemes: Int) async throws -> [String: Any] {
        let timestamp = Date()
        logger.info("Starting upload to /api/create with userID: \(userID) at \(timestamp)")
        let createURL = URL(string: "\(domain)/api/create")!
        var request = URLRequest(url: createURL)
        request.httpMethod = "POST"
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add user_id
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n".data(using: .utf8)!)
        body.append(userID.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add user_description
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"user_description\"\r\n\r\n".data(using: .utf8)!)
        body.append(userDescription.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add num_themes
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"num_themes\"\r\n\r\n".data(using: .utf8)!)
        body.append(String(numThemes).data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add image if exists
        if let imageData = imageData {
            logger.info("Adding image data to request")
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
            logger.info("Image data added to request")
        } else {
            logger.info("No image data provided")
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response type")
                throw NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.error("Server returned error: \(errorMessage) (Status: \(httpResponse.statusCode))")
                throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
            
            // Parse and return the JSON response
            if let jsonObject = try? JSONSerialization.jsonObject(with: data),
               let jsonDict = jsonObject as? [String: Any] {
                // Log the successful response
                let timestamp = Date()
                logger.info("Received response at \(timestamp): \(jsonDict)")
                return jsonDict
            } else {
                logger.error("Invalid JSON response")
                throw NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])
            }
        } catch {
            logger.error("Network request failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    func uploadToCreateAPI(sourceImageID: String, userID: String, userDescription: String, numThemes: Int) async throws -> [String: Any] {
        let timestamp = Date()
        logger.info("Starting upload to /api/roll with userID: \(userID) at \(timestamp)")
        let createURL = URL(string: "\(domain)/api/roll")!
        var request = URLRequest(url: createURL)
        request.httpMethod = "POST"
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add user_id
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n".data(using: .utf8)!)
        body.append(userID.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add source_image_id
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"source_image_id\"\r\n\r\n".data(using: .utf8)!)
        body.append(sourceImageID.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add user_description
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"user_description\"\r\n\r\n".data(using: .utf8)!)
        body.append(userDescription.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add num_themes
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"num_themes\"\r\n\r\n".data(using: .utf8)!)
        body.append(String(numThemes).data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response type")
                throw NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.error("Server returned error: \(errorMessage) (Status: \(httpResponse.statusCode))")
                throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
            
            // Parse and return the JSON response
            if let jsonObject = try? JSONSerialization.jsonObject(with: data),
               let jsonDict = jsonObject as? [String: Any] {
                // Log the successful response
                let timestamp = Date()
                logger.info("Received response at \(timestamp): \(jsonDict)")
                return jsonDict
            } else {
                logger.error("Invalid JSON response")
                throw NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])
            }
        } catch {
            logger.error("Network request failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    func fetchImage(resultImageID: String) async throws -> Data? {
        logger.info("Fetching image with resultImageID: \(resultImageID)")
        
        let imageURL = URL(string: "\(domain)/api/image/\(resultImageID)")!
        var request = URLRequest(url: imageURL)
        request.httpMethod = "GET"
        // Add user_id parameter from UserManager
        let userID = userManager.getCurrentUserID()
        let urlWithParams = URL(string: imageURL.absoluteString + "?user_id=\(userID)")!
        request.url = urlWithParams
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response type")
                throw NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.error("Server returned error: \(errorMessage) (Status: \(httpResponse.statusCode))")
                throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
            
            // Check if we received an image or a JSON response
            if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") {
                if contentType.contains("image/") {
                    logger.info("Received image data successfully, size: \(data.count) bytes")
                    return data
                } else if contentType.contains("application/json") {
                    // Parse the JSON to check if image is not ready yet
                    if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let ready = json["ready"] as? Bool, !ready {
                        let status = json["status"] as? String ?? "processing"
                        logger.info("Image not ready yet. Status: \(status)")
                        throw NSError(domain: "NetworkError", code: -2, userInfo: [
                            NSLocalizedDescriptionKey: "Image not ready yet",
                            "status": status,
                            "isImageNotReady": true
                        ])
                    }
                }
            }
            
            // If we get here and didn't return an image or throw a specific error,
            // something unexpected happened
            let responseText = String(data: data, encoding: .utf8) ?? "Unable to decode as text"
            logger.warning("Response did not contain an image. Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "none"), Response: \(responseText)")
            throw NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Response did not contain an image: \(responseText)"])
        } catch {
            logger.error("Failed to fetch image: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Add a new method with retry capability
    func fetchImageWithRetry(resultImageID: String, maxRetries: Int = 5, retryDelay: TimeInterval = 2.0) async throws -> Data? {
        var retryCount = 0
        var lastError: Error? = nil
        
        while retryCount < maxRetries {
            do {
                return try await fetchImage(resultImageID: resultImageID)
            } catch let error as NSError {
                lastError = error
                
                // Check if this is a "not ready" error that we should retry
                if error.domain == "NetworkError" && 
                   error.userInfo["isImageNotReady"] as? Bool == true {
                    
                    retryCount += 1
                    logger.info("Image not ready, retrying (\(retryCount)/\(maxRetries)) after \(retryDelay) seconds")
                    
                    // Wait before retrying
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                    continue
                } else {
                    // For other errors, don't retry
                    throw error
                }
            }
        }
        
        // If we've exhausted retries, throw the last error
        logger.error("Exceeded maximum retries (\(maxRetries)) for image fetch")
        throw lastError ?? NSError(domain: "NetworkError", code: -3, 
                                  userInfo: [NSLocalizedDescriptionKey: "Failed to fetch image after \(maxRetries) retries"])
    }
    
    // Add a new method to fetch user credits
    func fetchUserCredits(userID: String) async throws -> Int {
        logger.info("Fetching credits for userID: \(userID)")
        
        let creditsURL = URL(string: "\(domain)/api/credits/\(userID)")!
        var request = URLRequest(url: creditsURL)
        request.httpMethod = "GET"
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response type")
                throw NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.error("Server returned error: \(errorMessage) (Status: \(httpResponse.statusCode))")
                throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
            
            // Parse and return the credits
            if let jsonObject = try? JSONSerialization.jsonObject(with: data),
               let jsonDict = jsonObject as? [String: Any],
               let credits = jsonDict["credits"] as? Int {
                logger.info("Received credits: \(credits)")
                return credits
            } else {
                logger.error("Invalid JSON response or missing credits field")
                throw NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response or missing credits field"])
            }
        } catch {
            logger.error("Failed to fetch credits: \(error.localizedDescription)")
            throw error
        }
    }
    
    func useCredits(userID: String, credits: Int) async throws -> Int {
        logger.info("Using \(credits) credits for userID: \(userID)")
        
        let creditsURL = URL(string: "\(domain)/api/use_credits")!
        var request = URLRequest(url: creditsURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create the request body
        let requestBody: [String: Any] = [
            "user_id": userID,
            "credits": credits
        ]
        
        do {
            // Convert the dictionary to JSON data
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response type")
                throw NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.error("Server returned error: \(errorMessage) (Status: \(httpResponse.statusCode))")
                throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
            
            // Parse the response
            if let jsonObject = try? JSONSerialization.jsonObject(with: data),
               let jsonDict = jsonObject as? [String: Any],
               let remainingCredits = jsonDict["remaining_credits"] as? Int {
                logger.info("Successfully used \(credits) credits, remaining: \(remainingCredits)")
                return remainingCredits
            } else {
                logger.error("Invalid JSON response or missing remaining_credits field")
                throw NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response or missing remaining_credits field"])
            }
        } catch {
            logger.error("Failed to use credits: \(error.localizedDescription)")
            throw error
        }
    }
    
    func uploadImage(imageData: Data, userID: String) async throws -> String {
        logger.info("Uploading image for userID: \(userID)")
        
        let uploadURL = URL(string: "\(domain)/api/upload")!
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add user_id
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n".data(using: .utf8)!)
        body.append(userID.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add image
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response type")
                throw NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.error("Server returned error: \(errorMessage) (Status: \(httpResponse.statusCode))")
                throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
            
            // Parse and return the source_image_id
            if let jsonObject = try? JSONSerialization.jsonObject(with: data),
               let jsonDict = jsonObject as? [String: Any],
               let sourceImageID = jsonDict["source_image_id"] as? String {
                logger.info("Successfully uploaded image, source_image_id: \(sourceImageID)")
                return sourceImageID
            } else {
                logger.error("Invalid JSON response or missing source_image_id field")
                throw NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response or missing source_image_id field"])
            }
        } catch {
            logger.error("Failed to upload image: \(error.localizedDescription)")
            throw error
        }
    }
    
    func trackUserAction(userID: String, action: String, imageID: String? = nil) {
        logger.info("Tracking user action: \(action) for userID: \(userID)")
        
        let actionURL = URL(string: "\(domain)/api/action")!
        var request = URLRequest(url: actionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create the request body
        var requestBody: [String: Any] = [
            "user_id": userID,
            "action": action
        ]
        
        // Add imageID to metadata if provided
        if let imageID = imageID {
            let metadata: [String: String] = ["image_id": imageID]
            requestBody["metadata"] = metadata
        } else {
            requestBody["metadata"] = [:]
        }
        
        // Try to send the action but don't wait for response
        Task {
            do {
                // Convert the dictionary to JSON data
                let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
                request.httpBody = jsonData
                
                // Fire and forget - we don't care about the response
                let task = URLSession.shared.dataTask(with: request) { _, _, error in
                    if let error = error {
                        self.logger.error("Failed to track action: \(error.localizedDescription)")
                    }
                }
                task.resume()
            } catch {
                logger.error("Failed to serialize action data: \(error.localizedDescription)")
            }
        }
    }
    
    func initializeUser(userID: String) async {
        logger.info("Initializing user with ID: \(userID)")
        
        let initURL = URL(string: "\(domain)/api/init_user")!
        var request = URLRequest(url: initURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create the request body
        let requestBody: [String: Any] = [
            "user_id": userID
        ]
        
        do {
            // Convert the dictionary to JSON data
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData
            
            // Fire and forget - we don't wait for the response
            let task = URLSession.shared.dataTask(with: request) { _, response, error in
                if let error = error {
                    self.logger.error("Failed to initialize user: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    self.logger.error("Server returned error (Status: \(httpResponse.statusCode))")
                    return
                }
                
                self.logger.info("Successfully initialized user with ID: \(userID)")
            }
            task.resume()
        } catch {
            logger.error("Failed to serialize user initialization data: \(error.localizedDescription)")
        }
    }
} 
