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
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .offset(x: particle.offset.width, y: particle.offset.height)
                    .opacity(particle.opacity)
            }
        }
        .position(position)
        .onAppear {
            // Create explosion particles
            for _ in 0..<50 {
                let angle = Double.random(in: 0...2*Double.pi)
                let distance = CGFloat.random(in: 10...100)
                let speed = CGFloat.random(in: 0.5...2.0)
                let size = CGFloat.random(in: 3...8)
                
                // Add color variation to particles
                let particleColor = Bool.random() ? color : Color(
                    hue: Double.random(in: 0...1),
                    saturation: 0.8,
                    brightness: 1.0
                )
                
                let particle = FireworkParticle(
                    offset: CGSize.zero,
                    targetOffset: CGSize(
                        width: cos(angle) * distance,
                        height: sin(angle) * distance
                    ),
                    speed: speed,
                    opacity: 1.0,
                    size: size,
                    color: particleColor
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
            
            // Add a second wave of particles after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // Create secondary explosion particles
                for _ in 0..<30 {
                    let angle = Double.random(in: 0...2*Double.pi)
                    let distance = CGFloat.random(in: 30...120)
                    let speed = CGFloat.random(in: 0.8...2.5)
                    let size = CGFloat.random(in: 2...6)
                    
                    let particleColor = Color(
                        hue: Double.random(in: 0...1),
                        saturation: 0.9,
                        brightness: 1.0
                    )
                    
                    let particle = FireworkParticle(
                        offset: CGSize.zero,
                        targetOffset: CGSize(
                            width: cos(angle) * distance,
                            height: sin(angle) * distance
                        ),
                        speed: speed,
                        opacity: 1.0,
                        size: size,
                        color: particleColor
                    )
                    
                    withAnimation(.easeOut(duration: particle.speed)) {
                        var mutableParticle = particle
                        mutableParticle.offset = mutableParticle.targetOffset
                        mutableParticle.opacity = 0
                        particles.append(mutableParticle)
                    }
                }
            }
        }
    }
} 