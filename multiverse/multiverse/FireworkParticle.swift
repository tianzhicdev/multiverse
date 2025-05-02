import SwiftUI

struct FireworkParticle: Identifiable {
    let id = UUID()
    var offset: CGSize
    let targetOffset: CGSize
    let speed: CGFloat
    var opacity: Double
    var size: CGFloat = 5
    var color: Color = .white
} 