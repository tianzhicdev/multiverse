import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            Text("Multiverse.AI\nSimply Upload & Discover")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .transition(.opacity)
    }
}

#Preview {
    SplashScreenView()
} 