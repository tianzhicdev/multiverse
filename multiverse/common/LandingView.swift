import SwiftUI
import PhotosUI
import StoreKit
import SwiftData

struct LandingView: View {
    
    @State private var isDebugMode: Bool = false
    
    @State private var selectedImage: PhotosPickerItem?

    @State private var imageData: Data?
    
    @State private var sourceImageID: String?

    @State private var user_description: String = ""
    
    @State private var isUploading = false
    
    @State private var isSearching = false
    
    @State private var showError = false
    
    @State private var errorMessage = ""
    
    @State private var showBoxGrid = false
    
    @State private var showStore = false
    
    @State private var showFittingRoom = false

    @State private var searchText: String = ""
    @State private var selectedStyle: String = "Default"
    private let styleOptions = ["Default", "Modern", "Vintage", "Minimal", "Bold", "Custom"]
    
    @ObservedObject private var creditsViewModel = CreditsViewModel.shared
    
    @ObservedObject private var albumManager = AlbumManager.shared
    
    private let subscriptionProductID = "subscription.photons.500"
    
    var body: some View {
        NavigationStack {
            VStack {
                HeaderView()
                
                if AppConfig.getAppName() == "multiverse_shopping" {
                    Button(action: {
                        // Navigate to FittingRoomView
                        showFittingRoom = true
                    }) {
                        Text("Upload My Own")
                            .padding(8)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding(.bottom, 10)
                }
                
                PhotosPicker(selection: $selectedImage, matching: .images) {
                    if let imageData = imageData,
                        let uiImage = UIImage(data: imageData) {
                        // If an image is selected, display it
                        ZStack {
                            Color.clear // Background to ensure clipping works
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .aspectRatio(contentMode: .fill)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 200)
                        .background(Color.gray.opacity(0.2))  // Light gray background
                        .cornerRadius(8)            // Rounded corners
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    } else {
                        // If no image is selected, show a placeholder
                        Label("Select Image", systemImage: "photo")
                            .frame(maxWidth: .infinity)  // Takes full width
                            .frame(height: 200)          // Sets height
                            .background(Color.gray.opacity(0.2))  // Light gray background
                            .cornerRadius(8)            // Rounded corners
                    }
                }
                .onChange(of: selectedImage) { _, newValue in
                    Task {
                        if let data = try? await newValue?.loadTransferable(type: Data.self) {
                            imageData = data
                            isUploading = true
                            do {
                                guard let processedData = ImagePreprocessor.preprocessImage(data) else {
                                    throw NSError(domain: "ImageProcessingError", 
                                                 code: -1, 
                                                 userInfo: [NSLocalizedDescriptionKey: "Failed to preprocess image"])
                                }
                                
                                sourceImageID = try await NetworkService.shared.uploadImage(
                                    imageData: processedData,
                                    userID: UserManager.shared.getCurrentUserID()
                                )
                            } catch {
                                errorMessage = "Failed to upload image: \(error.localizedDescription)"
                                showError = true
                            }
                            isUploading = false
                        }
                    }
                }
                
                // Text input field for user to enter text
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $user_description)
                        .frame(minHeight: 100)
                        .padding(4)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(radius: 1)
                    
                    if user_description.isEmpty {
                        Text("Optional: Describe the focus of the image")
                            .foregroundColor(.gray)
                            .padding(.leading, 9) // 4 + 5
                            .padding(.top, 12) // 4 + 8
                    }
                }
                

                // Add spacing between text field and button
                Spacer()
                    .frame(height: 20)
                
                Button(action: {
                    if creditsViewModel.userCredits >= 10 {
                        Task {
                            isSearching = true
                            do {
                                // Try to deduct 10 credits
                                let remainingCredits = try await NetworkService.shared.useCredits(
                                    userID: UserManager.shared.getCurrentUserID(),
                                    credits: 10
                                )
                                
                                await MainActor.run {
                                    creditsViewModel.userCredits = remainingCredits
                                    
                                    // Track discover action
                                    NetworkService.shared.trackUserAction(
                                        userID: UserManager.shared.getCurrentUserID(),
                                        action: "discover"
                                    )
                                    
                                    performSearch()
                                    
                                    // Refresh the global credits view model
                                    CreditsViewModel.shared.refreshCredits()
                                }
                            } catch {
                                await MainActor.run {
                                    errorMessage = "Failed to use credits: \(error.localizedDescription)"
                                    showError = true
                                }
                            }
                            isSearching = false
                        }
                    } else {
                        errorMessage = "Insufficient credits. Each generation costs 10 credits."
                        showError = true
                    }
                }) {
                    HStack {
                        if isUploading {
                            Text("Uploading")
                            ProgressView()
                        } else {
                            Text("Discover 10x")
                            Image(systemName: "microbe.circle.fill")
                        }

                    }
                    .padding(8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(isUploading || sourceImageID == nil)  
                
                // Debug buttons that only appear when isDebugMode is true
                if isDebugMode {
                    Divider()
                        .padding(.vertical, 10)
                    
                    Text("Debug Options")
                        .font(.headline)
                    
                    HStack {
                        Button(action: {
                            UserManager.shared.clearUserID()
                            imageData = nil
                            sourceImageID = nil
                            user_description = ""
                        }) {
                            Text("Reset User")
                                .padding(8)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            UserManager.shared.resetTermsAcceptance()
                            creditsViewModel.refreshCredits()
                        }) {
                            Text("Reset Terms")
                                .padding(8)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.bottom, 10)
                }
            }
            .padding()  // Adds space around the entire VStack
            // Error alert that appears when showError is true
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            // Navigation to BoxGridView when showBoxGrid becomes true
            .navigationDestination(isPresented: $showBoxGrid) {
                BoxGridView(isDebugMode: isDebugMode)
            }
            // Navigation to StoreView when showStore becomes true
            .navigationDestination(isPresented: $showStore) {
                StoreView()
                    .onAppear {
                        // Track store check action
                        NetworkService.shared.trackUserAction(
                            userID: UserManager.shared.getCurrentUserID(),
                            action: "check_store"
                        )
                    }
            }
            .navigationDestination(isPresented: $showFittingRoom) {
                FittingRoomView()
            }
            .onAppear {
                // Ensure the UserManager is initialized when the view appears
                print("User ID: \(UserManager.shared.getCurrentUserID())")
                print("Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")")

                // Fetch user credits
                creditsViewModel.refreshCredits()
            }
        }
    }
    
    // Function to perform search with selected style
    private func performSearch() {
        guard let sourceImageID = sourceImageID else {
            errorMessage = "No image uploaded yet"
            showError = true
            return
        }
        
        Task {
            do {
                let result = try await ImageGenerationService.shared.generateImages(
                    sourceImageID: sourceImageID,
                    userID: UserManager.shared.getCurrentUserID(),
                    userDescription: user_description,
                    numThemes: 9,
                    album: albumManager.getCurrentAlbumMode()
                )
                
                // Refresh the global credits view model
                CreditsViewModel.shared.refreshCredits()
                
                // Navigate to BoxGridView
                await MainActor.run {
                    showBoxGrid = true
                }
            } catch {
                print("Error performing search: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = "Search failed: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

// Preview provider for SwiftUI previews
// This allows developers to see how the view looks in Xcode's preview canvas
#Preview {
    LandingView()
}
