import SwiftUI
import SwiftData

struct BoxGridView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [UploadItem]
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)
    let totalBoxes = 9
    
    // User credits state
    @State private var userCredits: Int = 0
    @State private var isLoadingCredits: Bool = false
    
    // Reroll state
    @State private var isRerolling: Bool = false
    @State private var reloadTrigger: Int = 0
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            let rowCount = ceil(Double(totalBoxes) / 3.0)
            let boxHeight = (screenHeight - (4 * (rowCount - 1))) / rowCount
            
            VStack {
                // Credits display and Reroll button at the top
                HStack {
                    Button(action: rerollImages) {
                        HStack {
                            if isRerolling {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text("Reroll")
                        }
                        .padding(8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .disabled(isRerolling)
                    }
                    
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
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(0..<totalBoxes, id: \.self) { index in
                            BoxView(number: index + 1, items: items, reloadTrigger: reloadTrigger)
                                .frame(height: boxHeight)
                        }
                    }
                }
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
        }
    }
    
    // Function to reroll images
    private func rerollImages() {
        guard !isRerolling else { return }
        
        isRerolling = true
        
        // Get the stored inputs for rerolling
        let generationInputs = APIResponseStore.shared.getLastGenerationInputs()
        let sourceImageData = APIResponseStore.shared.getLastSourceImage()
        
        // If we don't have the required inputs, we can't reroll
        guard let inputs = generationInputs else {
            print("Can't reroll: No generation inputs available")
            isRerolling = false
            return
        }
        
        Task {
            do {
                // Use the shared service to generate new images
                let result = try await ImageGenerationService.shared.generateImages(
                    imageData: sourceImageData,
                    userID: UserManager.shared.getCurrentUserID(),
                    userDescription: inputs.userDescription,
                    numThemes: totalBoxes
                )
                
                // Refresh user credits
                await fetchUserCredits()
                
                // Increment the reload trigger to force all boxes to reload
                await MainActor.run {
                    reloadTrigger += 1
                }
                
                await MainActor.run {
                    isRerolling = false
                }
            } catch {
                print("Error rerolling images: \(error.localizedDescription)")
                await MainActor.run {
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
    BoxGridView()
        .modelContainer(for: UploadItem.self, inMemory: true)
}
