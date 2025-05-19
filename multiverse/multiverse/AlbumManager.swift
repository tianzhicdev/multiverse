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
    @State private var showAlbumList = false
    
    var body: some View {
        HStack {
            Toggle(isOn: $albumManager.isMyAlbum) {
                Text("My Album")
                    .font(.caption)
            }
            .toggleStyle(SwitchToggleStyle(tint: .blue))
            
            Spacer()
            
            Button {
                showAlbumList = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .font(.caption)
                    Text("Manage")
                        .font(.caption)
                }
            }
            .foregroundColor(.blue)
        }
        .padding(.horizontal)
        .sheet(isPresented: $showAlbumList) {
            AlbumListView()
        }
    }
}

 