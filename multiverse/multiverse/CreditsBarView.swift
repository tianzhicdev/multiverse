import SwiftUI

struct CreditsBarView: View {
    @State private var userCredits: Int = 0
    @State private var isLoadingCredits: Bool = false
    @State private var showStore: Bool = false
    
    var body: some View {
        HStack(alignment: .center) {
            HStack {
                if isLoadingCredits {
                    ProgressView()
                } else {
                    Image(systemName: "microbe.circle.fill")
                        .foregroundColor(.green)
                    Text("\(userCredits)").foregroundColor(.green)
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
            fetchUserCredits()
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
    
    // Function to refresh credits (can be called from parent views)
    func refreshCredits() {
        fetchUserCredits()
    }
}

#Preview {
    CreditsBarView()
} 