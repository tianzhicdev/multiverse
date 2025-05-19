import SwiftUI

struct HeaderView: View {
    @ObservedObject private var albumManager = AlbumManager.shared
    @ObservedObject private var creditsViewModel = CreditsViewModel.shared
    @State private var showAlbumList = false
    @State private var showStore = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Left side - Album controls
            Button {
                showAlbumList = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "suit.heart.fill")
                        .font(.caption)
                    Text("Themes")
                        .font(.caption)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green, lineWidth: 1)
                )
                .frame(height: 30)
            }
            .foregroundColor(.green)
            
            Button {
                albumManager.isMyAlbum.toggle()
            } label: {
                HStack(spacing: 4) {
                    Text("Use My Themes")
                        .font(.caption)
                    Image(systemName: albumManager.isMyAlbum ? "checkmark.circle.fill" : "circle")
                        .font(.caption)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green, lineWidth: 1)
                )
                .frame(height: 30)
            }
            .foregroundColor(.green)
            
            // Right side - Credits controls
            Button {
                creditsViewModel.fetchUserCredits()
            } label: {
                HStack(spacing: 4) {
                    if creditsViewModel.isLoadingCredits {
                        ProgressView()
                    } else {
                        Image(systemName: "microbe.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("\(creditsViewModel.userCredits)")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green, lineWidth: 1)
                )
                .frame(height: 30)
            }
            
            Button {
                showStore = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "storefront.circle.fill")
                        .font(.caption)
                    Text("Store")
                        .font(.caption)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green, lineWidth: 1)
                )
                .frame(height: 30)
            }
            .foregroundColor(.green)
        }
        .padding(.horizontal)
        .sheet(isPresented: $showAlbumList) {
            AlbumListView()
        }
        .sheet(isPresented: $showStore) {
            StoreView()
        }
    }
    
    // Function to refresh credits (can be called from parent views)
    func refreshCredits() {
        creditsViewModel.refreshCredits()
    }
}

#Preview {
    HeaderView()
} 