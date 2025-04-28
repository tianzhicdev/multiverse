import SwiftUI

struct FullImageView: View {
    let uiImage: UIImage
    @State private var opacity = 0.0
    @State private var scale = 0.8
    @State private var rotation = 0.0
    @State private var showFireworks = false
    
    var body: some View {
        ZStack {
            // The image
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(opacity)
                .scaleEffect(scale)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    // Reveal the image with rotation immediately
                    withAnimation(.easeInOut(duration: 0.5)) {
                        opacity = 1.0
                        scale = 1.1
                        rotation = 5
                    }
                    
                    // Settle the image with spring animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            scale = 1.0
                            rotation = 0
                        }
                    }
                    
                    // Show fireworks celebration after image is revealed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        showFireworks = true
                    }
                }
            
            if showFireworks {
                FireworksView()
            }
        }
    }
} 