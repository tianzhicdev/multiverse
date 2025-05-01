// This is the main file for the app's user interface
// It's named ContentView.swift because it contains the primary view of the application

// Import necessary frameworks
import SwiftUI        // SwiftUI is Apple's framework for building user interfaces
                      // It provides tools to create buttons, text fields, images, etc.
import PhotosUI       // PhotosUI is Apple's framework for accessing the photo library
                      // It allows users to select photos from their device
import StoreKit       // StoreKit is Apple's framework for in-app purchases and subscriptions

// Main view structure for the app
// In SwiftUI, everything is built using structures (struct) that conform to the View protocol
struct LandingView: View {
    // Reference to user manager that handles the UUID
    @State private var userManager = UserManager.shared
    
    // Debug mode state
    @State private var isDebugMode: Bool = false
    
    // State variables to manage the UI and data
    // @State is a property wrapper that tells SwiftUI to watch for changes
    // When these values change, SwiftUI automatically updates the UI
    
    // Stores the photo selected by the user from the photo picker
    @State private var selectedImage: PhotosPickerItem?
    
    // Stores the actual image data (the bytes that make up the image)
    @State private var imageData: Data?
    
    // Stores the source image ID
    @State private var sourceImageID: String?
    
    // Stores the text entered by the user
    @State private var user_description: String = ""
    
    // Tracks whether an upload is in progress
    @State private var isUploading = false
    
    // Tracks whether a search is in progress
    @State private var isSearching = false
    
    // Controls whether to show an error message
    @State private var showError = false
    
    // Stores the text of the error message
    @State private var errorMessage = ""
    
    // Controls navigation to the BoxGridView
    @State private var showBoxGrid = false
    
    // Controls navigation to the store view
    @State private var showStore = false
    
    // Search related states
    @State private var searchText: String = ""
    @State private var selectedStyle: String = "Default"
    // Predefined styles list
    private let styleOptions = ["Default", "Modern", "Vintage", "Minimal", "Bold", "Custom"]
    
    // User credits
    @State private var userCredits: Int = 0
    @State private var isLoadingCredits: Bool = false
    
    // StoreKit product identifiers
    // REPLACE THESE with your actual product identifiers from App Store Connect
    private let subscriptionProductID = "subscription.standard"
    
    // The body property is required by the View protocol
    // It defines what the view looks like
    var body: some View {
        // NavigationStack provides navigation functionality
        // It allows moving between different screens in the app
        NavigationStack {
            VStack {
                // Add the CreditsBarView here
                CreditsBarView()
                
                // PhotosPicker is a built-in component for selecting photos
                // It shows the device's photo library
                PhotosPicker(selection: $selectedImage, matching: .images) {
                    // Conditional view based on whether an image is selected
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
                                    userID: userManager.getCurrentUserID()
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
                    if userCredits >= 10 {
                        Task {
                            isSearching = true
                            do {
                                // Try to deduct 10 credits
                                let remainingCredits = try await NetworkService.shared.useCredits(
                                    userID: userManager.getCurrentUserID(),
                                    credits: 10
                                )
                                
                                await MainActor.run {
                                    userCredits = remainingCredits
                                    performSearch()
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
                            Image(systemName: "waveform.circle")
                        }

                    }
                    .padding(8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(isUploading || sourceImageID == nil)  
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
            }
            .onAppear {
                // Ensure the UserManager is initialized when the view appears
                print("User ID: \(userManager.getCurrentUserID())")
                // Fetch user credits
                fetchUserCredits()
            }
        }
    }
    
    // Function to fetch user credits
    private func fetchUserCredits() {
        isLoadingCredits = true
        
        Task {
            do {
                let credits = try await NetworkService.shared.fetchUserCredits(
                    userID: userManager.getCurrentUserID()
                )
                
                await MainActor.run {
                    userCredits = credits
                    isLoadingCredits = false
                }
            } catch {
                print("Error fetching credits: \(error.localizedDescription)")
                await MainActor.run {
                    isLoadingCredits = false
                }
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
                    userID: userManager.getCurrentUserID(),
                    userDescription: user_description,
                    numThemes: 9
                )
                
                // Refresh user credits
                fetchUserCredits()
                
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
