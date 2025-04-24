import SwiftUI

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