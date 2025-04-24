import SwiftUI

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