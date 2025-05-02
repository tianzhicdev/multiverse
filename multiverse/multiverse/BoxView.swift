import SwiftUI
import AVFoundation
// FakeLoadingBar is now in a separate file

struct BoxView: View {
    let number: Int
    let items: [UploadItem]
    let reloadTrigger: Int
    let isDebugMode: Bool
    let onCreditsUpdated: ((Int) -> Void)?  // Add callback for credit updates
    let onLoadingChanged: ((Int, Bool) -> Void)? // Add callback for loading state changes
    
    @State private var imageData: Data?
    @State private var isLoading = false {
        didSet {
            // Notify when loading state changes
            if oldValue != isLoading {
                onLoadingChanged?(number, isLoading)
            }
        }
    }
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showFullImage = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var wiggleAmount = 0.0
    @State private var themeName: String = ""
    @State private var showSuccessAlert = false
    @State private var successMessage = ""
    @State private var currentLoadTask: Task<Void, Never>?  // Add task tracking
    @State private var requestID: String = ""  // Add request ID state
    @State private var resultImageID: String = ""  // Add result image ID state
    @State private var shouldReveal = false  // Determines if we should reveal (wiggle + sound) when the image appears
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white)
                .aspectRatio(0.67, contentMode: .fit)
                .cornerRadius(8)
            
            if let imageData = imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .rotationEffect(.degrees(wiggleAmount))
                    .onTapGesture {
                        showFullImage = true
                    }
                    .onAppear {
                        if shouldReveal {
                            // Start wiggle animation
                            withAnimation(.interpolatingSpring(stiffness: 300, damping: 5)) {
                                wiggleAmount = 5
                            }
                            
                            // Return to normal after wiggle
                            withAnimation(.interpolatingSpring(stiffness: 300, damping: 5).delay(0.2)) {
                                wiggleAmount = 0
                            }
                            
                            // Play sound and mark reveal as done
                            playSound()
                            shouldReveal = false
                        }
                    }
                
                // Theme name overlay
                VStack {
                    Spacer()
                    if isDebugMode {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("RID: \(requestID.prefix(5))")
                                .font(.caption)
                                .foregroundColor(.white)
                            Text("IID: \(resultImageID.prefix(5))")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .padding(4)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                        .padding(4)
                    }
                    Text(themeName)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        .padding(8)
                }
            } else if isLoading {
                VStack {
                    FakeLoadingBar(resetTrigger: reloadTrigger)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    if isDebugMode {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("RID: \(requestID.prefix(5))")
                                .font(.caption)
                                .foregroundColor(.black)
                            Text("IID: \(resultImageID.prefix(5))")
                                .font(.caption)
                                .foregroundColor(.black)
                        }
                        .padding(4)
                        .background(Color.white.opacity(0.6))
                        .cornerRadius(4)
                        .padding(4)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            } else {
                Text("\(number)")
                    .font(.title)
                    .foregroundColor(.black)
            }
        }
        .task {
            await loadImage()
        }
        .onChange(of: reloadTrigger) { oldValue, newValue in
            if oldValue != newValue {
                // Cancel any ongoing load task
                currentLoadTask?.cancel()
                // Reset state
                imageData = nil
                isLoading = true
                // Start new load task
                currentLoadTask = Task {
                    await loadImage()
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) { 
                showFullImage = false
            }
        } message: {
            Text(successMessage)
        }
        .sheet(isPresented: $showFullImage) {
            if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                FullImageView(
                    uiImage: uiImage,
                    themeName: themeName,
                    resultImageID: resultImageID,
                    onCreditsUpdated: onCreditsUpdated
                )
            }
        }
    }
    
    private func playSound() {
        guard let soundURL = Bundle.main.url(forResource: "ding5", withExtension: "mp3") else {
            print("Sound file not found")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.play()
        } catch {
            print("Failed to play sound: \(error.localizedDescription)")
        }
    }
    
    private func loadImage() async {
        // Create a new task and store it
        let task = Task {
            isLoading = true
            print("BoxGridView: Loading image for box #\(number)")
            
            do {
                // Check if task was cancelled
                try Task.checkCancellation()
                
                // Wait for API response
                var apiResponse: APIResponse?
                var retryCount = 0
                let maxRetries = 100 // Maximum 20 retries
                let retryDelay = 3.0 // 3 second between retries
                
                while retryCount < maxRetries {
                    // Check if task was cancelled
                    try Task.checkCancellation()
                    
                    if let response = APIResponseStore.shared.getLastResponse() {
                        apiResponse = response
                        break
                    }
                    
                    print("BoxGridView: Waiting for API response for box #\(number), retry \(retryCount + 1)/\(maxRetries)")
                    retryCount += 1
                    
                    // Wait before trying again
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                }
                
                // Check if task was cancelled
                try Task.checkCancellation()
                
                // Check if we got the API response after retries
                if let apiResponse = apiResponse, !apiResponse.images.isEmpty {
                    // Adjust the index (number-1) to get the right image from the array
                    let adjustedIndex = (number - 1) % apiResponse.images.count
                    let themeImage = apiResponse.images[adjustedIndex]
                    
                    print("BoxGridView: Box #\(number) using resultImageID: \(themeImage.resultImageID) with theme: \(themeImage.themeName)")
                    
                    // Set theme name and IDs
                    await MainActor.run {
                        self.themeName = themeImage.themeName
                        self.requestID = apiResponse.requestID
                        self.resultImageID = themeImage.resultImageID
                    }
                    
                    // Check if the image is already cached
                    if let cachedData = ImageCache.shared.imageData(for: themeImage.resultImageID) {
                        print("BoxGridView: Using cached image for box #\(number), size: \(cachedData.count) bytes")
                        await MainActor.run {
                            self.imageData = cachedData
                            isLoading = false
                        }
                        return // Skip network fetch
                    }
                    
                    // Check if task was cancelled
                    try Task.checkCancellation()
                    
                    shouldReveal = true
                    // Use the fetchImageWithRetry method which already has its own retry mechanism
                    let processedImageData = try await NetworkService.shared.fetchImageWithRetry(
                        resultImageID: themeImage.resultImageID,
                        maxRetries: 100,  // Maximum 100 retries
                        retryDelay: 2.0   // 2 seconds between retries
                    )
                    
                    // Check if task was cancelled
                    try Task.checkCancellation()
                    
                    if let imageData = processedImageData {
                        print("BoxGridView: Successfully loaded image for box #\(number), data size: \(imageData.count) bytes")
                        
                        // Convert the image data to UIImage to verify it's valid
                        if let uiImage = UIImage(data: imageData) {
                            print("BoxGridView: Successfully converted data to UIImage for box #\(number)")
                            
                            await MainActor.run {
                                self.imageData = imageData
                                isLoading = false
                            }
                            
                            // Store the downloaded image in cache for future reuse
                            ImageCache.shared.setImageData(imageData, for: themeImage.resultImageID)
                        } else {
                            print("BoxGridView: Failed to convert data to UIImage for box #\(number)")
                            throw NSError(domain: "ImageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data received"])
                        }
                    } else {
                        print("BoxGridView: No image data received for box #\(number)")
                        throw NSError(domain: "ImageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No image data received"])
                    }
                } else {
                    print("BoxGridView: No API response found after \(maxRetries) retries for box #\(number)")
                    throw NSError(domain: "DataError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No result image IDs found after waiting. Please upload an image first."])
                }
            } catch {
                // Only show error if task wasn't cancelled
                if !Task.isCancelled {
                    print("BoxGridView: Error loading image for box #\(number): \(error.localizedDescription)")
                    await MainActor.run {
                        isLoading = false
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
        }
        
        // Store the task
        currentLoadTask = task
    }
}

#Preview {
    BoxView(number: 1, items: [], reloadTrigger: 0, isDebugMode: false, onCreditsUpdated: nil, onLoadingChanged: nil)
} 