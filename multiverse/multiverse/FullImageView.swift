import SwiftUI

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