import SwiftUI

struct AlbumListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var albumThemes: [AlbumTheme] = []
    @State private var isLoading = true
    @State private var errorMessage: String = ""
    @State private var showError = false
    @State private var showAddThemeSheet = false
    @State private var showCreateThemeSheet = false
    @State private var newThemeID = ""
    @State private var newThemeName = ""
    @State private var newThemeDescription = ""
    @State private var isCreatingTheme = false
    @State private var showCopiedToast = false
    @State private var copiedThemeName = ""
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading your Themes...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if albumThemes.isEmpty {
                    VStack {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                            .padding()
                        
                        Text("Your Themes are empty")
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
                                
                                Spacer()
                                
                                Button(action: {
                                    copyToClipboard(theme.themeID)
                                    copiedThemeName = theme.name
                                    showCopiedToast = true
                                    
                                    // Hide toast after 2 seconds
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        showCopiedToast = false
                                    }
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                            .padding(.vertical, 8)
                        }
                        .onDelete(perform: deleteThemes)
                    }
                    .listStyle(.plain)
                    .overlay(
                        showCopiedToast ?
                        VStack {
                            Spacer()
                            Text("Copied \(copiedThemeName) ID to clipboard")
                                .padding()
                                .background(Color.black.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .padding(.bottom)
                        }
                        : nil
                    )
                }
            }
            .navigationTitle("My Themes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showAddThemeSheet = true
                        } label: {
                            Label("Add Existing Theme", systemImage: "plus.app")
                        }
                        
                        Button {
                            showCreateThemeSheet = true
                        } label: {
                            Label("Create New Theme", systemImage: "square.and.pencil")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showAddThemeSheet) {
                addThemeView
            }
            .sheet(isPresented: $showCreateThemeSheet) {
                createThemeView
            }
            .onAppear {
                fetchAlbumThemes()
            }
        }
    }
    
    private var addThemeView: some View {
        NavigationStack {
            Form {
                Section(header: Text("Enter Theme ID")) {
                    TextField("Theme ID", text: $newThemeID)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section {
                    Button("Add to Themes") {
                        addThemeToAlbum()
                    }
                    .disabled(newThemeID.isEmpty)
                }
            }
            .navigationTitle("Add Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        newThemeID = ""
                        showAddThemeSheet = false
                    }
                }
            }
        }
    }
    
    private var createThemeView: some View {
        NavigationStack {
            Form {
                Section(header: Text("Theme Details")) {
                    TextField("Theme Name", text: $newThemeName)
                    TextField("Theme Description", text: $newThemeDescription)
                        .frame(height: 100, alignment: .top)
                        .multilineTextAlignment(.leading)
                }
            }
            .navigationTitle("Create New Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        resetCreateThemeForm()
                        showCreateThemeSheet = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createNewTheme()
                    }
                    .disabled(newThemeName.isEmpty || newThemeDescription.isEmpty || isCreatingTheme)
                }
            }
            .overlay(
                Group {
                    if isCreatingTheme {
                        ProgressView("Creating theme...")
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .shadow(radius: 4)
                    }
                }
            )
        }
    }
    
    private func resetCreateThemeForm() {
        newThemeName = ""
        newThemeDescription = ""
    }
    
    private func createNewTheme() {
        guard !newThemeName.isEmpty, !newThemeDescription.isEmpty else { return }
        
        isCreatingTheme = true
        
        Task {
            do {
                let userID = UserManager.shared.getCurrentUserID()
                let themeID = try await NetworkService.shared.createTheme(
                    userID: userID,
                    name: newThemeName,
                    description: newThemeDescription
                )
                
                await MainActor.run {
                    isCreatingTheme = false
                    resetCreateThemeForm()
                    showCreateThemeSheet = false
                    
                    // Refresh album themes
                    fetchAlbumThemes()
                }
            } catch {
                await MainActor.run {
                    isCreatingTheme = false
                    errorMessage = "Error creating theme: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
    
    private func addThemeToAlbum() {
        guard !newThemeID.isEmpty else { return }
        
        Task {
            do {
                let userID = UserManager.shared.getCurrentUserID()
                let success = try await NetworkService.shared.addToAlbum(
                    userID: userID,
                    themeID: newThemeID
                )
                
                if success {
                    await MainActor.run {
                        // Reset form and close sheet
                        newThemeID = ""
                        showAddThemeSheet = false
                        
                        // Refresh the album list
                        fetchAlbumThemes()
                    }
                } else {
                    throw NSError(domain: "AlbumError", code: -1, 
                                 userInfo: [NSLocalizedDescriptionKey: "Failed to add theme to album"])
                }
            } catch {
                await MainActor.run {
                    newThemeID = ""
                    showAddThemeSheet = false
                    self.errorMessage = "Error adding theme: \(error.localizedDescription)"
                    self.showError = true
                }
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