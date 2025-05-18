import SwiftUI

class AlbumManager: ObservableObject {
    static let shared = AlbumManager()
    
    @Published var isMyAlbum: Bool = false
    
    private init() {}
    
    func getCurrentAlbumMode() -> String {
        return isMyAlbum ? "my_album" : "default"
    }
    
    func toggleAlbumMode() {
        isMyAlbum.toggle()
    }
}

struct AlbumToggleView: View {
    @ObservedObject private var albumManager = AlbumManager.shared
    
    var body: some View {
        Toggle(isOn: $albumManager.isMyAlbum) {
            Text("My Album")
                .font(.caption)
        }
        .toggleStyle(SwitchToggleStyle(tint: .blue))
        .padding(.horizontal)
    }
} 