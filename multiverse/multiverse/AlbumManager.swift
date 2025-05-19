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
                        
            Button {
                showAlbumList = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "suit.heart.fill")
                        .font(.caption)
                    Text("Manage Saved Themes")
                        .font(.caption)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 1)
                )
            }
            .foregroundColor(.blue)
                        
            Spacer()

            HStack(spacing: 4) {
                Text("Use My Themes")
                    .font(.caption)
                Toggle("", isOn: $albumManager.isMyAlbum)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .labelsHidden()
            }

        }
        .padding(.horizontal)
        .sheet(isPresented: $showAlbumList) {
            AlbumListView()
        }
    }
}

 