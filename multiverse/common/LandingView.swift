import SwiftUI
import PhotosUI
import StoreKit
import SwiftData

struct LandingView: View {
    
    @State private var isDebugMode: Bool = false
    
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
    
    @State private var showDescriptionPopup = false

    @State private var searchText: String = ""
    @State private var selectedStyle: String = "Default"
    private let styleOptions = ["Default", "Modern", "Vintage", "Minimal", "Bold", "Custom"]
    
    @ObservedObject private var creditsViewModel = CreditsViewModel.shared
    
    @ObservedObject private var albumManager = AlbumManager.shared
    
    private let subscriptionProductID = "subscription.photons.500"
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Add universe background image
                Image("universe")
                    .resizable()
                    .scaledToFill()
                    .edgesIgnoringSafeArea(.all)
                
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
                    
                    Spacer()
                    
                    // Upload Image View as a square in the middle
                    UploadImageView(
                        imageData: $imageData,
                        imageID: $sourceImageID,
                        placeholder: "Select Image",
                        imageHeight: 200,
                        isUploading: $isUploading
                    )
                    .frame(width: 200, height: 200)
                    .onChange(of: sourceImageID) { oldValue, newValue in
                        if newValue != nil {
                            // Show description popup whenever image changes
                            showDescriptionPopup = true
                        }
                    }
                    
                    Spacer()
                    
                    // Discover button as a square with robot_search image
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
                        ZStack {
                            if isSearching || isUploading {
                                ProgressView()
                            } else {
                                Image("robot_search")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                            }
                        }
                        .frame(width: 70, height: 70)
                        .background(Color.clear)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.green, lineWidth: 1)
                        )
                    }
                    .disabled(sourceImageID == nil || isSearching || isUploading)
                    .padding(.bottom, 20)
                    
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
                .padding()
            }
            // Error alert that appears when showError is true
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            // Add sheet presentation for the description popup
            .sheet(isPresented: $showDescriptionPopup) {
                VStack(spacing: 20) {
                    Text("Describe the focus of your image")
                        .font(.headline)
                    
                    TextField("Description", text: $user_description, axis: .vertical)
                        .lineLimit(4...)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                    
                    HStack {
                        Button("Cancel") {
                            showDescriptionPopup = false
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("Submit") {
                            showDescriptionPopup = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .padding()
                .presentationDetents([.height(250)])
                .presentationDragIndicator(.visible)
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
