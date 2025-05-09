import SwiftUI

// Create an ObservableObject to manage credits state
class CreditsViewModel: ObservableObject {
    // Shared instance for global access
    static let shared = CreditsViewModel()
    
    @Published var userCredits: Int = 0
    @Published var isLoadingCredits: Bool = false
    
    func refreshCredits() {
        fetchUserCredits()
    }
    
    // Function to fetch user credits
    func fetchUserCredits() {
        isLoadingCredits = true
        
        Task {
            do {
                let credits = try await NetworkService.shared.fetchUserCredits(
                    userID: UserManager.shared.getCurrentUserID()
                )
                
                await MainActor.run {
                    self.userCredits = credits
                    self.isLoadingCredits = false
                }
            } catch {
                print("Error fetching credits: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoadingCredits = false
                }
            }
        }
    }
}

struct CreditsBarView: View {
    // Use the shared ViewModel instance
    @ObservedObject var viewModel: CreditsViewModel
    @State private var showStore: Bool = false
    
    // Default initializer uses the shared instance
    init(viewModel: CreditsViewModel = CreditsViewModel.shared) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        HStack(alignment: .center) {
            HStack {
                if viewModel.isLoadingCredits {
                    ProgressView()
                } else {
                    Image(systemName: "microbe.circle.fill")
                        .foregroundColor(.green)
                    Text("\(viewModel.userCredits)").foregroundColor(.green)
                }
            }
            .padding(10)
            .cornerRadius(8)
            .padding(.leading, 5)

            Spacer()
            
            Button(action: {
                showStore = true
            }) {
                HStack {
                    Image(systemName: "storefront.circle.fill")
                        .foregroundColor(.white)
                    Text("Store")
                        .foregroundColor(.white)
                }
                .padding(10)
                .background(Color(.green))
                .cornerRadius(8)
                .padding(.trailing, 5)
            }
            
            NavigationLink(destination: StoreView(), isActive: $showStore) {
                EmptyView()
            }
        }
        // .padding(.horizontal)
        .padding(.bottom, 10)
        .onAppear {
            viewModel.fetchUserCredits()
        }.onTapGesture {
            viewModel.fetchUserCredits()
        }
    }
    
    // Function to refresh credits (can be called from parent views)
    func refreshCredits() {
        viewModel.refreshCredits()
    }
}

#Preview {
    CreditsBarView()
} 