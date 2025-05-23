import SwiftUI
import PhotosUI

struct FittingRoomView: View {
    // State for person image
    @State private var personImageData: Data?
    @State private var personImageID: String?
    
    // State for clothing image
    @State private var clothImageData: Data?
    @State private var clothingImageID: String?
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
                        
                        UploadImageView(
                            imageData: $personImageData,
                            imageID: $personImageID,
                            placeholder: "Select Person Image",
                            imageHeight: 200
                        )
                    }
                    
                    // Clothing image picker
                    VStack(alignment: .leading) {
                        Text("Select Clothing Image")
                            .font(.headline)
                        
                        UploadImageView(
                            imageData: $clothImageData,
                            imageID: $clothingImageID,
                            placeholder: "Select Clothing Image",
                            imageHeight: 200
                        )
                        .onChange(of: clothingImageID) { _, newID in
                            if let newID = newID {
                                createFashionTheme(clothingImageID: newID)
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
                        .onChange(of: selectedClothType) { _, _ in
                            if let imageID = clothingImageID {
                                createFashionTheme(clothingImageID: imageID)
                            }
                        }
                    }
                    
                    // Submit button
                    Button(action: {
                        submitImages()
                    }) {
                        if isProcessing {
                            HStack {
                                Text("Processing")
                                ProgressView().progressViewStyle(CircularProgressViewStyle())
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
                    .disabled(isProcessing || personImageID == nil || themeID == nil)
                    
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
                                ProgressView().progressViewStyle(CircularProgressViewStyle())
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
    
    private func createFashionTheme(clothingImageID: String) {
        Task {
            do {
                themeID = try await NetworkService.shared.createFashionTheme(
                    imageID: clothingImageID,
                    type: selectedClothType,
                    userID: UserManager.shared.getCurrentUserID()
                )
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create fashion theme: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func submitImages() {
        guard let sourceImageID = personImageID, let clothThemeID = themeID else {
            errorMessage = "Please select both person and clothing images"
            showError = true
            return
        }
        
        isProcessing = true
        
        Task {
            do {
                // Start the fashion request
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

#Preview {
    FittingRoomView()
} 