import SwiftUI
import SwiftData

struct BoxGridView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [UploadItem]
    
    // Debug mode parameter
    let isDebugMode: Bool
    
    // Grid spacing constant for both column and row
    private let gridSpacing: CGFloat = 1
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 3)
    let totalBoxes = 9
    
    // User credits state
    @State private var userCredits: Int = 0
    @State private var isLoadingCredits: Bool = false
    
    // Reroll state
    @State private var isRerolling: Bool = false
    @State private var reloadTrigger: Int = 0
    
    // Error state
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    
    // Loading tracking state
    @State private var loadingBoxes = Set<Int>()
    
    // Lifecycle tracking
    @State private var viewAppeared = false
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            let rowCount = ceil(Double(totalBoxes) / 3.0)
            // Calculate each cell width considering the horizontal spacing between columns
            let cellWidth = (screenWidth - (gridSpacing * 2)) / 3
            // Maintain the 0.67 width : height aspect ratio from BoxView
            let boxHeight = cellWidth / 0.67
            
            VStack {
                
                // Debug info display
                if isDebugMode {
                    if let apiResponse = APIResponseStore.shared.getLastResponse() {
                        let requestIDPrefix = String(apiResponse.requestID.prefix(5))
                        Text("RID: \(requestIDPrefix)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                    }
                }
                
                // Add CreditsBarView at the top
                CreditsBarView()
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: gridSpacing) {
                        ForEach(0..<totalBoxes, id: \.self) { index in
                            BoxView(
                                number: index + 1,
                                items: items,
                                reloadTrigger: reloadTrigger,
                                isDebugMode: isDebugMode,
                                onCreditsUpdated: { newCredits in
                                    userCredits = newCredits
                                },
                                onLoadingChanged: { number, isLoading in
                                    handleLoadingStateChanged(number: number, isLoading: isLoading)
                                }
                            )
                                .frame(height: boxHeight)
                                .onAppear {
                                    // Add to loading boxes when the BoxView appears
                                    loadingBoxes.insert(index + 1)
                                    updateLoadingSoundState()
                                }
                                .onChange(of: reloadTrigger) { _, _ in
                                    // When reloading, mark box as loading
                                    loadingBoxes.insert(index + 1)
                                    updateLoadingSoundState()
                                }
                        }
                    }
                }

            HStack {
                Spacer()
                Button(action: {
                    if userCredits >= 10 {
                        rerollImages()
                    } else {
                        errorMessage = "Insufficient credits. Each reroll costs 10 credits."
                        showError = true
                    }
                }) {
                    HStack {
                        if isRerolling {
                            ProgressView()
                        } else {
                            Text("Re-Discover 10x")
                            Image(systemName: "microbe.circle.fill")
                        }
                    }
                    .padding(8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(isRerolling)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 10)
            }
            
        }
        .onAppear {
            // Check if we have API response data
            if let apiResponse = APIResponseStore.shared.getLastResponse() {
                print("BoxGridView: Loaded API response with \(apiResponse.images.count) images")
            } else {
                print("BoxGridView: No API response data found")
            }
            
            // Fetch user credits when view appears
            fetchUserCredits()
            
            // Mark view as appeared to track lifecycle
            viewAppeared = true
            updateLoadingSoundState()
        }
        .onDisappear {
            // Mark view as disappeared 
            viewAppeared = false
            // Stop sounds when view disappears
            AudioManager.shared.stopLoadingSound()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // Function to handle loading state changes
    private func handleLoadingStateChanged(number: Int, isLoading: Bool) {
        if isLoading {
            loadingBoxes.insert(number)
        } else {
            loadingBoxes.remove(number)
        }
        updateLoadingSoundState()
    }
    
    // Update the audio state based on loading state and view lifecycle
    private func updateLoadingSoundState() {
        if viewAppeared && !loadingBoxes.isEmpty {
            // If at least one box is loading, play the sound
            AudioManager.shared.startLoadingSound()
        } else {
            // If no boxes are loading or view is not visible, stop the sound
            AudioManager.shared.stopLoadingSound()
        }
    }
    
    // Function to reroll images
    private func rerollImages() {
        guard !isRerolling else { return }
        
        isRerolling = true
        
        // Get the stored inputs for rerolling
        let generationInputs = APIResponseStore.shared.getLastGenerationInputs()
        let lastResponse = APIResponseStore.shared.getLastResponse()
        
        // If we don't have the required inputs, we can't reroll
        guard let inputs = generationInputs,
              let response = lastResponse else {
            print("Can't reroll: No generation inputs or response available")
            isRerolling = false
            return
        }
        
        Task {
            do {
                 NetworkService.shared.trackUserAction(
                    userID: UserManager.shared.getCurrentUserID(),
                        action: "rediscover"
                    )
                // First use the credits
                let remainingCredits = try await NetworkService.shared.useCredits(
                    userID: UserManager.shared.getCurrentUserID(),
                    credits: 10
                )
                
                // Update credits display
                await MainActor.run {
                    // userCredits = remainingCredits
                    
                    // Refresh the global credits view model
                    CreditsViewModel.shared.refreshCredits()
                }
                
                // Use the shared service to generate new images
                let result = try await ImageGenerationService.shared.generateImages(
                    sourceImageID: response.sourceImageID,
                    userID: UserManager.shared.getCurrentUserID(),
                    userDescription: inputs.userDescription,
                    numThemes: totalBoxes
                )
                
                // Clear cached images because we will fetch new ones
                ImageCache.shared.clearAll()
                
                // Set rerolling to false
                await MainActor.run {
                    reloadTrigger += 1
                    isRerolling = false
                    
                    // Refresh the global credits view model
                    CreditsViewModel.shared.refreshCredits()
                }
            } catch {
                print("Error rerolling images: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = "Failed to reroll: \(error.localizedDescription)"
                    showError = true
                    isRerolling = false
                }
            }
        }
    }
    
    // Function to fetch user credits
    private func fetchUserCredits() {
        isLoadingCredits = true
        
        Task {
            do {
                let credits = try await NetworkService.shared.fetchUserCredits(
                    userID: UserManager.shared.getCurrentUserID()
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
}

#Preview {
    BoxGridView(isDebugMode: false)
        .modelContainer(for: UploadItem.self, inMemory: true)
}
