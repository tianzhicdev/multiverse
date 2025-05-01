import SwiftUI
import CoreGraphics
import ImageIO

struct FakeLoadingBar: View {
    @State private var isFlipped: Bool = false
    let resetTrigger: Int
    
    var body: some View {
        VStack {
            ZStack {
                // Load and display telescope.gif
                if let url = Bundle.main.url(forResource: "telescope", withExtension: "gif") {
                    GIFView(url: url, onAnimationComplete: {
                        // Flip the image after each cycle
                        isFlipped.toggle()
                    })
                    .scaleEffect(x: isFlipped ? -1 : 1) // Flip vertically when isFlipped is true
                }
            }
        }
        .onChange(of: resetTrigger) { _, _ in
            // Just reset the flip state when trigger changes
            isFlipped = false
        }
    }
}

// Helper GIF view to display and loop the GIF
struct GIFView: UIViewRepresentable {
    private let url: URL
    private let onAnimationComplete: () -> Void
    
    init(url: URL, onAnimationComplete: @escaping () -> Void) {
        self.url = url
        self.onAnimationComplete = onAnimationComplete
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        
        // Create GIF image view
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        
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
            
            // Set up animation
            imageView.animationImages = images
            imageView.animationDuration = duration
            imageView.animationRepeatCount = 0 // Loop forever
            imageView.startAnimating()
            
            // Set up animation completion tracking
            context.coordinator.setupAnimationObserver(for: imageView, duration: duration)
        }
        
        view.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
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