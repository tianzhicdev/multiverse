import SwiftUI

struct AlbumListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var albumThemes: [AlbumTheme] = []
    @State private var isLoading = true
    @State private var errorMessage: String = ""
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading your album...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if albumThemes.isEmpty {
                    VStack {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                            .padding()
                        
                        Text("Your album is empty")
                            .font(.headline)
                        
                        Text("Save themes to view them here")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(albumThemes) { theme in
                            HStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .foregroundColor(.green)
                                    .font(.title3)
                                Text(theme.name)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 8)
                        }
                        .onDelete(perform: deleteThemes)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("My Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                fetchAlbumThemes()
            }
        }
    }
    
    private func fetchAlbumThemes() {
        Task {
            do {
                let userID = UserManager.shared.getCurrentUserID()
                let themes = try await NetworkService.shared.getUserAlbum(userID: userID)
                
                await MainActor.run {
                    self.albumThemes = themes
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Error loading album: \(error.localizedDescription)"
                    self.showError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    private func deleteThemes(at offsets: IndexSet) {
        Task {
            let userID = UserManager.shared.getCurrentUserID()
            
            for index in offsets {
                let theme = albumThemes[index]
                do {
                    let success = try await NetworkService.shared.removeFromAlbum(
                        userID: userID,
                        themeID: theme.themeID
                    )
                    
                    if success {
                        await MainActor.run {
                            // Remove from local array
                            albumThemes.remove(at: index)
                        }
                    } else {
                        throw NSError(domain: "AlbumError", code: -1, 
                                     userInfo: [NSLocalizedDescriptionKey: "Failed to remove theme from album"])
                    }
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Error removing theme: \(error.localizedDescription)"
                        self.showError = true
                    }
                    break
                }
            }
        }
    }
} 