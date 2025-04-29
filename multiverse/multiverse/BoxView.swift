import SwiftUI
import AVFoundation

struct BoxView: View {
    let number: Int
    let items: [UploadItem]
    let reloadTrigger: Int
    let onCreditsUpdated: ((Int) -> Void)?  // Add callback for credit updates
    
    @State private var imageData: Data?
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showFullImage = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var wiggleAmount = 0.0
    @State private var themeName: String = ""
    @State private var showSuccessAlert = false
    @State private var successMessage = ""
    @State private var currentLoadTask: Task<Void, Never>?  // Add task tracking
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(0.67, contentMode: .fit)
                .cornerRadius(8)
            
            if let imageData = imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    // .blur(radius: 5)
                    .clipped()
                    .rotationEffect(.degrees(wiggleAmount))
                    .onTapGesture {
                        showFullImage = true
                    }
                    .onAppear {
                        // Start wiggle animation
                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 5)) {
                            wiggleAmount = 5
                        }
                        
                        // Return to normal after wiggle
                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 5).delay(0.2)) {
                            wiggleAmount = 0
                        }
                        
                        playSound()
                    }
                
                // Theme name overlay
                VStack {
                    Spacer()
                    Text(themeName)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        .padding(8)
                }
            } else if isLoading {
                FakeLoadingBar(resetTrigger: reloadTrigger)
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
                VStack {
                    ZStack {
                        FullImageView(uiImage: uiImage)
                        
                        VStack {
                            Spacer()
                            Text(themeName)
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(8)
                                .padding(.bottom, 40)
                        }
                    }
                    
                    Button("Download") {
                        // Check credits before attempting download
                        Task {
                            do {
                                let userID = UserManager.shared.getCurrentUserID()
                                
                                // First check if user has enough credits
                                let currentCredits = try await NetworkService.shared.fetchUserCredits(
                                    userID: userID
                                )
                                
                                if currentCredits < 10 {
                                    await MainActor.run {
                                        errorMessage = "Insufficient credits. Each download costs 10 credits."
                                        showError = true
                                        showFullImage = false
                                    }
                                    return
                                }
                                
                                // Try to deduct 10 credits
                                let remainingCredits = try await NetworkService.shared.useCredits(
                                    userID: userID,
                                    credits: 10
                                )
                                
                                // Credits deducted successfully, save the image
                                await MainActor.run {
                                    UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
                                    // Show success alert
                                    successMessage = "Image saved successfully! You have \(remainingCredits) credits remaining."
                                    showSuccessAlert = true
                                    // Notify parent about credit update
                                    onCreditsUpdated?(remainingCredits)
                                }
                            } catch {
                                // Handle error - likely insufficient credits
                                print("Failed to download image: \(error.localizedDescription)")
                                await MainActor.run {
                                    // Show error alert
                                    errorMessage = "Download failed: Insufficient credits. Each download costs 10 credits."
                                    showError = true
                                    showFullImage = false
                                }
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .overlay(
                        HStack {
                            Text("10")
                                .font(.caption)
                            Image(systemName: "creditcard")
                        }
                        .padding(4)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(4)
                        .padding(.trailing, 8),
                        alignment: .trailing
                    )
                    
                    Button("Close") {
                        showFullImage = false
                    }
                }
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
                    
                    // Set theme name
                    await MainActor.run {
                        self.themeName = themeImage.themeName
                    }
                    
                    // Check if task was cancelled
                    try Task.checkCancellation()
                    
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

struct FakeLoadingBar: View {
    @State private var progress: Double = 0.0
    @State private var timer: Timer?
    let resetTrigger: Int  // Add reset trigger
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(lineWidth: 8)
                    .opacity(0.3)
                    .foregroundColor(Color.gray)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(self.progress, 1.0)))
                    .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                    .foregroundColor(.blue)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.linear, value: progress)
            }
            .frame(width: 60, height: 60)
            
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .padding(.top, 4)
        }
        .onAppear {
            startFakeLoading()
        }
        .onChange(of: resetTrigger) { _, _ in
            // Reset and restart loading when trigger changes
            timer?.invalidate()
            progress = 0.0
            startFakeLoading()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func startFakeLoading() {
        // Total time: 2 minutes (120 seconds)
        // Update roughly every 200ms
        let totalUpdates = 600
        let totalTime = 120.0
        
        timer = Timer.scheduledTimer(withTimeInterval: totalTime / Double(totalUpdates), repeats: true) { timer in
            if progress < 0.99 {
                // Add some randomness to the progress
                let randomIncrement = Double.random(in: 0.0...0.005)
                
                // Slow down as we approach 99%
                let factor = 1.0 - progress
                
                // Apply update with randomness and slowdown
                progress = min(progress + randomIncrement * factor, 0.99)
            } else {
                // Stop at 99%
                timer.invalidate()
            }
        }
    }
}

#Preview {
    BoxView(number: 1, items: [], reloadTrigger: 0, onCreditsUpdated: nil)
} 