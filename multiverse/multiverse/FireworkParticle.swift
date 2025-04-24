import SwiftUI

struct FireworkParticle: Identifiable {
    let id = UUID()
    var offset: CGSize
    let targetOffset: CGSize
    let speed: CGFloat
    var opacity: Double
} 