import SwiftUI
import CoreGraphics
import ImageIO

struct FakeLoadingBar: View {
    @State private var isFlipped: Bool = Bool.random()
    @State private var speedFactor: Double = Double.random(in: 0.7...1.3)
    let resetTrigger: Int
    
    var body: some View {
        ZStack {
            // Load and display telescope.gif
            if let url = Bundle.main.url(forResource: "telescope", withExtension: "gif") {
                GIFView(url: url, speedFactor: speedFactor, onAnimationComplete: {
                    // Flip the image after each cycle
                    isFlipped.toggle()
                    // Randomize speed for next cycle
                    speedFactor = Double.random(in: 0.7...1.3)
                })
                .scaleEffect(x: isFlipped ? -1 : 1) // Flip vertically when isFlipped is true
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            }
        }
        .onChange(of: resetTrigger) { _, _ in
            // Reset the flip state and randomize speed when trigger changes
            isFlipped = false
            speedFactor = Double.random(in: 0.7...1.3)
        }
    }
}

// Helper GIF view to display and loop the GIF
struct GIFView: UIViewRepresentable {
    private let url: URL
    private let speedFactor: Double
    private let onAnimationComplete: () -> Void
    
    init(url: URL, speedFactor: Double = 1.0, onAnimationComplete: @escaping () -> Void) {
        self.url = url
        self.speedFactor = speedFactor
        self.onAnimationComplete = onAnimationComplete
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        
        // Create GIF image view
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill // Changed to scaleAspectFill to fill the container
        
        // Load the GIF
        if let gifData = try? Data(contentsOf: url),
           let source = CGImageSourceCreateWithData(gifData as CFData, nil) {
            
            // Get frame count
            let count = CGImageSourceGetCount(source)
            var images = [UIImage]()
            var duration: TimeInterval = 0
            
            // Extract all frames
            for i in 0..<count {
                if let image = CGImageSourceCreateImageAtIndex(source, i, nil) {
                    images.append(UIImage(cgImage: image))
                    
                    // Get frame duration
                    if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                       let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any],
                       let delayTime = gifProperties[kCGImagePropertyGIFDelayTime as String] as? Double {
                        duration += delayTime
                    }
                }
            }
            
            // Apply speed factor to duration
            let adjustedDuration = duration * speedFactor
            
            // Set up animation
            imageView.animationImages = images
            imageView.animationDuration = adjustedDuration
            imageView.animationRepeatCount = 0 // Loop forever
            imageView.startAnimating()
            
            // Set up animation completion tracking
            context.coordinator.setupAnimationObserver(for: imageView, duration: adjustedDuration)
        }
        
        view.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Add clipsToBounds to ensure content doesn't exceed view boundaries
        view.clipsToBounds = true
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update logic if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject {
        var parent: GIFView
        private var timer: Timer?
        
        init(parent: GIFView) {
            self.parent = parent
        }
        
        func setupAnimationObserver(for imageView: UIImageView, duration: TimeInterval) {
            // Stop any existing timer
            timer?.invalidate()
            
            // Create a timer that fires slightly after each animation cycle completes
            timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: true) { [weak self] _ in
                if imageView.isAnimating {
                    DispatchQueue.main.async {
                        self?.parent.onAnimationComplete()
                    }
                }
            }
        }
        
        deinit {
            timer?.invalidate()
        }
    }
}

#Preview {
    FakeLoadingBar(resetTrigger: 0)
}