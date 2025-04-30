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
struct ContentView: View {
    // Reference to user manager that handles the UUID
    @State private var userManager = UserManager.shared
    
    // Debug mode state
    @State private var isDebugMode: Bool = true
    
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
            // VStack arranges its children vertically (one above another)
            VStack {
                // Credits display and Reroll button at the top
                HStack {
                    
                    Spacer()
                    
                    HStack {
                        if isLoadingCredits {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "creditcard")
                                .foregroundColor(.green)
                        }
                        Text("Credits: \(userCredits)")
                            .fontWeight(.semibold)
                    }
                    .padding(8)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .shadow(radius: 1)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                
                // PhotosPicker is a built-in component for selecting photos
                // It shows the device's photo library
                PhotosPicker(selection: $selectedImage, matching: .images) {
                    // Conditional view based on whether an image is selected
                    if let imageData = imageData,
                        let uiImage = UIImage(data: imageData) {
                        // If an image is selected, display it
                        Image(uiImage: uiImage)
                            .resizable()        // Allows the image to be resized
                            .scaledToFit()      // Maintains aspect ratio while fitting
                            .frame(maxHeight: 300)  // Sets maximum height
                    } else {
                        // If no image is selected, show a placeholder
                        Label("Select Image", systemImage: "photo")
                            .frame(maxWidth: .infinity)  // Takes full width
                            .frame(height: 200)          // Sets height
                            .background(Color.gray.opacity(0.2))  // Light gray background
                            .cornerRadius(10)            // Rounded corners
                    }
                }
                // This code runs when the selected image changes
                .onChange(of: selectedImage) { _, newValue in
                    // The closure has two parameters:
                    // - _ (underscore): This is a placeholder for the old value that we don't need
                    // - newValue: This is the new value of selectedImage
                    // The 'in' keyword marks the beginning of the closure's body
                    // Task creates a new asynchronous context
                    // It allows us to run code that might take time (like loading an image)
                    // without freezing the user interface
                    // Think of it like creating a separate thread of execution
                    // that runs in the background while the rest of the app continues to work
                    Task {
                        if let data = try? await newValue?.loadTransferable(type: Data.self) {
                            imageData = data
                            // Start upload process
                            isUploading = true
                            do {
                                // Preprocess the image before uploading
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
                TextField("Enter description", text: $user_description)
                    .textFieldStyle(RoundedBorderTextFieldStyle())  // Styled with rounded border
                    .padding()  // Adds space around the text field
                

                VStack {
                    
                    Menu {
                        ForEach(styleOptions, id: \.self) { style in
                            Button(style) {
                                selectedStyle = style
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedStyle)
                            Image(systemName: "chevron.down")
                        }
                        .padding(8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding(.trailing)
                    
                    if selectedStyle == "Custom" {
                        TextField("Search...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.leading)
                    }
                }
                .padding(.bottom)
                
                // Button to perform search
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
                        if isSearching {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Text("Search")
                        }
                        Text("10")
                            .font(.caption)
                        Image(systemName: "creditcard")
                    }
                    .padding(8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(isUploading || sourceImageID == nil)  // Disable if uploading or no source image ID
                
                // Store Button
                Button(action: {
                    showStore = true
                }) {
                    HStack {
                        Image(systemName: "cart")
                        Text("Go to Store")
                    }
                    .padding(8)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.top, 10)
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
    ContentView()
}
