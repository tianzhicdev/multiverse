import SwiftUI
import SwiftData
import WebKit
import AVFoundation

struct BoxGridView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [UploadItem]
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)
    let totalBoxes = 12
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            let rowCount = ceil(Double(totalBoxes) / 3.0)
            let boxHeight = (screenHeight - (4 * (rowCount - 1))) / rowCount
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(0..<totalBoxes, id: \.self) { index in
                        BoxView(number: index + 1, items: items)
                            .frame(height: boxHeight)
                    }
                }
            }
        }
    }
}

struct BoxView: View {
    let number: Int
    let items: [UploadItem]
    @State private var imageData: Data?
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showFullImage = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var wiggleAmount = 0.0
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(0.67, contentMode: .fit)
            
            if let imageData = imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .blur(radius: 5)
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
            } else if isLoading {
                ProgressView()
            } else {
                Text("\(number)")
                    .font(.title)
                    .foregroundColor(.black)
            }
        }
        .task {
            await loadImage()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showFullImage) {
            
            if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                VStack {
                    ZStack {
                        FullImageView(uiImage: uiImage)
                    }
                    
                    Button("Download") {
                        // The three nil parameters represent:
                        // 1. The completion target (object to notify when saving completes)
                        // 2. The completion selector (method to call when saving completes)
                        // 3. The context info (additional data to pass to the completion method)
                        UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
                    }
                    
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
        isLoading = true
        print("BoxGridView: Loading image for box #\(number)")
        
        do {
            // Wait for API response with retry mechanism
            var apiResponse: [String: Any]?
            var resultImageIDs: [String]?
            var retryCount = 0
            let maxRetries = 20 // Maximum 20 retries
            let retryDelay = 1.0 // 1 second between retries
            
            while retryCount < maxRetries {
                if let storedResponse = UserDefaults.standard.dictionary(forKey: "lastAPIResponse"),
                   let storedImageIDs = storedResponse["result_image_ids"] as? [String] {
                    apiResponse = storedResponse
                    resultImageIDs = storedImageIDs
                    break
                }
                
                print("BoxGridView: Waiting for API response for box #\(number), retry \(retryCount + 1)/\(maxRetries)")
                retryCount += 1
                
                // Wait before trying again
                try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            }
            
            // Check if we got the API response after retries
            if let resultImageIDs = resultImageIDs, let apiResponse = apiResponse {
                // Adjust the index (number-1) to get the right image ID from the array
                let adjustedIndex = (number - 1) % resultImageIDs.count
                let resultImageID = resultImageIDs[adjustedIndex]
                print("API Response: \(apiResponse)")
                print("BoxGridView: Box #\(number) using resultImageID: \(resultImageID)")
                
                // Use the fetchImageWithRetry method which already has its own retry mechanism
                let processedImageData = try await NetworkService.shared.fetchImageWithRetry(
                    resultImageID: resultImageID,
                    maxRetries: 100,  // Maximum 100 retries
                    retryDelay: 2.0   // 2 seconds between retries
                )
                
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
            print("BoxGridView: Error loading image for box #\(number): \(error.localizedDescription)")
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct FullImageView: View {
    let uiImage: UIImage
    @State private var opacity = 0.0
    @State private var scale = 0.8
    @State private var rotation = 0.0
    @State private var showFireworks = false
    @State private var showDrumGif = true
    
    var body: some View {
        ZStack {
            // Drum GIF
            if showDrumGif {
                GifImageView(gifName: "drum")
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // The image
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(opacity)
                .scaleEffect(scale)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    // Hide drum gif after 2.5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showDrumGif = false
                        }
                        
                        // At 2.6s (2.5s + 0.1s delay): Reveal the image with rotation
                        withAnimation(.easeInOut(duration: 0.5).delay(0.1)) {
                            opacity = 1.0
                            scale = 1.1
                            rotation = 5
                        }
                    }
                    
                    // At 3.2s (2.5s + 0.7s): Settle the image with spring animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            scale = 1.0
                            rotation = 0
                        }
                    }
                    
                    // At 3.0s: Show fireworks celebration after image is revealed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                        showFireworks = true
                    }
                }
            
            if showFireworks {
                FireworksView()
            }
        }
    }
}

struct GifImageView: UIViewRepresentable {
    let gifName: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let gifURL = Bundle.main.url(forResource: gifName, withExtension: "gif") {
            let request = URLRequest(url: gifURL)
            uiView.load(request)
        }
    }
}

struct FireworksView: View {
    @State private var fireworks: [Firework] = []
    
    let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            ForEach(fireworks) { firework in
                FireworkView(position: firework.position, color: firework.color)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(timer) { _ in
            if fireworks.count < 15 {
                addFirework()
            }
        }
        .onAppear {
            // Add initial fireworks
            for _ in 0..<5 {
                addFirework()
            }
        }
    }
    
    func addFirework() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        let position = CGPoint(
            x: CGFloat.random(in: screenWidth * 0.1...screenWidth * 0.9),
            y: CGFloat.random(in: screenHeight * 0.1...screenHeight * 0.9)
        )
        
        let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange, .pink]
        let color = colors.randomElement() ?? .yellow
        
        let firework = Firework(position: position, color: color)
        fireworks.append(firework)
        
        // Remove the firework after some time
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if let index = fireworks.firstIndex(where: { $0.id == firework.id }) {
                fireworks.remove(at: index)
            }
        }
    }
}

struct Firework: Identifiable {
    let id = UUID()
    let position: CGPoint
    let color: Color
}

struct FireworkView: View {
    let position: CGPoint
    let color: Color
    
    @State private var scale = 0.1
    @State private var opacity = 1.0
    @State private var particles: [FireworkParticle] = []
    
    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
                    .offset(x: particle.offset.width, y: particle.offset.height)
                    .opacity(particle.opacity)
            }
        }
        .position(position)
        .onAppear {
            // Create explosion particles
            for _ in 0..<20 {
                let angle = Double.random(in: 0...2*Double.pi)
                let distance = CGFloat.random(in: 5...50)
                let speed = CGFloat.random(in: 0.5...1.5)
                
                let particle = FireworkParticle(
                    offset: CGSize.zero,
                    targetOffset: CGSize(
                        width: cos(angle) * distance,
                        height: sin(angle) * distance
                    ),
                    speed: speed,
                    opacity: 1.0
                )
                particles.append(particle)
            }
            
            // Animate particles
            withAnimation(.easeOut(duration: 0.1)) {
                scale = 1.0
            }
            
            // Animate each particle
            for i in particles.indices {
                withAnimation(.easeOut(duration: particles[i].speed)) {
                    particles[i].offset = particles[i].targetOffset
                    particles[i].opacity = 0
                }
            }
            
            // Fade out after explosion
            withAnimation(.easeOut(duration: 0.8).delay(0.5)) {
                opacity = 0
            }
        }
    }
}

struct FireworkParticle: Identifiable {
    let id = UUID()
    var offset: CGSize
    let targetOffset: CGSize
    let speed: CGFloat
    var opacity: Double
}

#Preview {
    BoxGridView()
        .modelContainer(for: UploadItem.self, inMemory: true)
} 
