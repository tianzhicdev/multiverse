import SwiftUI
import PhotosUI

struct FittingRoomView: View {
    // State for person image
    @State private var selectedPersonImage: PhotosPickerItem?
    @State private var personImageData: Data?
    @State private var personImageID: String?
    
    // State for clothing image
    @State private var selectedClothImage: PhotosPickerItem?
    @State private var clothImageData: Data?
    @State private var themeID: String?
    
    // State for cloth type selection
    @State private var selectedClothType = "upper_body"
    private let clothTypeOptions = ["upper_body", "lower_body", "dress"]
    
    // State for processing status
    @State private var isProcessing = false
    @State private var resultImage: UIImage?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var requestStatus: String?
    @State private var requestID: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Person image picker
                    VStack(alignment: .leading) {
                        Text("Select Person Image")
                            .font(.headline)
                        
                        PhotosPicker(selection: $selectedPersonImage, matching: .images) {
                            if let personImageData = personImageData,
                               let uiImage = UIImage(data: personImageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 200)
                                    .cornerRadius(8)
                            } else {
                                Label("Select Person Image", systemImage: "person")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 200)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                        .onChange(of: selectedPersonImage) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    personImageData = data
                                    personImageID = nil // Reset ID when new image is selected
                                }
                            }
                        }
                    }
                    
                    // Clothing image picker
                    VStack(alignment: .leading) {
                        Text("Select Clothing Image")
                            .font(.headline)
                        
                        PhotosPicker(selection: $selectedClothImage, matching: .images) {
                            if let clothImageData = clothImageData,
                               let uiImage = UIImage(data: clothImageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 200)
                                    .cornerRadius(8)
                            } else {
                                Label("Select Clothing Image", systemImage: "tshirt")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 200)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                        .onChange(of: selectedClothImage) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    clothImageData = data
                                    themeID = nil // Reset ID when new image is selected
                                }
                            }
                        }
                    }
                    
                    // Cloth type picker
                    VStack(alignment: .leading) {
                        Text("Select Clothing Type")
                            .font(.headline)
                        
                        Picker("Clothing Type", selection: $selectedClothType) {
                            ForEach(clothTypeOptions, id: \.self) { option in
                                Text(option.replacingOccurrences(of: "_", with: " ").capitalized)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // Submit button
                    Button(action: {
                        submitImages()
                    }) {
                        if isProcessing {
                            HStack {
                                Text("Processing")
                                ProgressView()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        } else {
                            Text("Try It On")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .disabled(isProcessing || personImageData == nil || clothImageData == nil)
                    
                    // Result status
                    if let requestStatus = requestStatus {
                        VStack(alignment: .leading) {
                            Text("Status: \(requestStatus)")
                                .font(.headline)
                            
                            if requestStatus == "completed", let resultImage = resultImage {
                                Image(uiImage: resultImage)
                                    .resizable()
                                    .scaledToFit()
                                    .cornerRadius(8)
                            } else if requestStatus == "pending" {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Virtual Fitting Room")
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func submitImages() {
        guard let personData = personImageData, let clothData = clothImageData else {
            errorMessage = "Please select both person and clothing images"
            showError = true
            return
        }
        
        isProcessing = true
        
        Task {
            do {
                // Step 1: Upload person image if not already uploaded
                if personImageID == nil {
                    personImageID = try await NetworkService.shared.uploadImage(
                        imageData: personData,
                        userID: UserManager.shared.getCurrentUserID()
                    )
                }
                
                // Step 2: Create theme for clothing if not already created
                if themeID == nil {
                    themeID = try await NetworkService.shared.createTheme(
                        imageData: clothData,
                        type: selectedClothType,
                        userID: UserManager.shared.getCurrentUserID()
                    )
                }
                
                // Step 3: Start the fashion request
                guard let sourceImageID = personImageID, let clothThemeID = themeID else {
                    throw NSError(domain: "FittingRoom", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get image IDs"])
                }
                
                let response = try await NetworkService.shared.startFashionRequest(
                    sourceImageID: sourceImageID,
                    themeID: clothThemeID,
                    userID: UserManager.shared.getCurrentUserID()
                )
                
                await MainActor.run {
                    requestID = response.requestID
                    requestStatus = response.status
                    isProcessing = false
                }
                
                // If we have a request ID, start polling for result
                if let requestID = response.requestID {
                    try await checkRequestStatus(requestID: requestID)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Error: \(error.localizedDescription)"
                    showError = true
                    isProcessing = false
                }
            }
        }
    }
    
    private func checkRequestStatus(requestID: String) async throws {
        guard let resultImageID = self.requestID else {
            throw NSError(domain: "FittingRoom", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing result image ID"])
        }
        
        // Start polling for the result
        let maxAttempts = 60 // Poll for up to 5 minutes (5 seconds × 60)
        var attempts = 0
        
        while attempts < maxAttempts {
            do {
                let status = try await NetworkService.shared.checkImageStatus(
                    resultImageID: resultImageID,
                    userID: UserManager.shared.getCurrentUserID()
                )
                
                await MainActor.run {
                    self.requestStatus = status.status
                }
                
                // If the image is ready, fetch and display it
                if status.ready {
                    let imageData = try await NetworkService.shared.fetchImage(
                        resultImageID: resultImageID,
                        userID: UserManager.shared.getCurrentUserID()
                    )
                    
                    await MainActor.run {
                        if let image = UIImage(data: imageData) {
                            self.resultImage = image
                            self.requestStatus = "completed"
                        }
                    }
                    
                    return
                }
                
                // Wait before next poll
                try await Task.sleep(nanoseconds: 5 * 1_000_000_000) // 5 seconds
                attempts += 1
            } catch {
                await MainActor.run {
                    self.errorMessage = "Error checking status: \(error.localizedDescription)"
                    self.showError = true
                }
                
                throw error
            }
        }
        
        // If we've reached the max attempts without success
        throw NSError(domain: "FittingRoom", code: 2, userInfo: [NSLocalizedDescriptionKey: "Request timed out"])
    }
}

// NetworkService extension to support new APIs
extension NetworkService {
    func uploadImage(imageData: Data, userID: String) async throws -> String {
        let url = URL(string: "\(baseURL)/api/upload")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add user_id field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(userID)\r\n".data(using: .utf8)!)
        
        // Add image field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "NetworkService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        let json = try JSONDecoder().decode([String: String].self, from: data)
        guard let sourceImageID = json["source_image_id"] else {
            throw NSError(domain: "NetworkService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing source_image_id in response"])
        }
        
        return sourceImageID
    }
    
    func createTheme(imageData: Data, type: String, userID: String) async throws -> String {
        let url = URL(string: "\(baseURL)/api/theme")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add user_id field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(userID)\r\n".data(using: .utf8)!)
        
        // Add type field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"type\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(type)\r\n".data(using: .utf8)!)
        
        // Add image field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"cloth.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "NetworkService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        let json = try JSONDecoder().decode([String: String].self, from: data)
        guard let themeID = json["theme_id"] else {
            throw NSError(domain: "NetworkService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing theme_id in response"])
        }
        
        return themeID
    }
    
    func startFashionRequest(sourceImageID: String, themeID: String, userID: String) async throws -> (requestID: String?, status: String) {
        let url = URL(string: "\(baseURL)/api/fashion")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let parameters: [String: Any] = [
            "source_image_id": sourceImageID,
            "theme_id": themeID,
            "user_id": userID
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "NetworkService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        let json = try JSONDecoder().decode([String: String].self, from: data)
        return (requestID: json["request_id"], status: json["status"] ?? "pending")
    }
    
    func checkImageStatus(resultImageID: String, userID: String) async throws -> (ready: Bool, status: String) {
        let url = URL(string: "\(baseURL)/api/image/\(resultImageID)?user_id=\(userID)")!
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "NetworkService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        // If the response is an image (status code 200 and content-type is image/*)
        if httpResponse.statusCode == 200 && httpResponse.mimeType?.contains("image") == true {
            return (ready: true, status: "ready")
        }
        
        // Otherwise parse the JSON status response
        let json = try JSONDecoder().decode([String: Any].self, from: data) as? [String: Any]
        let ready = json?["ready"] as? Bool ?? false
        let status = json?["status"] as? String ?? "unknown"
        
        return (ready: ready, status: status)
    }
    
    func fetchImage(resultImageID: String, userID: String) async throws -> Data {
        let url = URL(string: "\(baseURL)/api/image/\(resultImageID)?user_id=\(userID)")!
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              httpResponse.mimeType?.contains("image") == true else {
            throw NSError(domain: "NetworkService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response or not an image"])
        }
        
        return data
    }
}

#Preview {
    FittingRoomView()
} 