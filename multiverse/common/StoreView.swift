import SwiftUI
import StoreKit
import Foundation

// StoreView for handling purchases and subscriptions
struct StoreView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var products: [Product] = []
    @State private var isPurchasing = false
    @State private var purchasingProductID: String?
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var isRestoring = false
    @State private var userCredits = 0
    @State private var showCreditsPopup = false
    var dismissAction: () -> Void = {}
    
    // Custom product information dictionary
    let productInfo: [String: (title: String, description: String)] = [
        // Consumables
        "photons100": (title: "Small Pack", description: "100 photons to explore the multiverse."),
        "photons200": (title: "Medium Pack", description: "200 photons to explore the multiverse."),
        "photons500": (title: "Large Pack", description: "500 photons to explore the multiverse."),
        "photons1200": (title: "Mega Pack", description: "1200 photons to explore the multiverse."),
        // Subscriptions
        "premium": (title: "Premium Subscription", description: "Get 500 photons every month.")
    ]
    
    var body: some View {
        ZStack {
            // Add universe background image
            Image("universe")
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.leading)
                    
                    Spacer()
                }
                .padding(.top)
                
                Image(systemName: "storefront.circle.fill")
                    .font(.largeTitle)
                    .padding()
                    .foregroundColor(.green)
                
                // Restore button at the top
                Button(action: restorePurchases) {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle")
                        Text(isRestoring ? "Restoring..." : "Restore Purchases")
                    }
                    .frame(minWidth: 200)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isRestoring)
                .padding(.bottom)
                
                if products.isEmpty {
                    ProgressView("Loading products...")
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Subscription products section
                            if !subscriptionProducts.isEmpty {
                                Text("Subscriptions")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                
                                ForEach(subscriptionProducts, id: \.id) { product in
                                    ProductView(
                                        product: product,
                                        isPurchasing: isPurchasing && purchasingProductID == product.id,
                                        buttonText: "Subscribe",
                                        action: { purchaseProduct(product) },
                                        customTitle: productInfo[product.id]?.title,
                                        customDescription: productInfo[product.id]?.description
                                    )
                                }
                            }
                            
                            // Consumable products section
                            if !consumableProducts.isEmpty {
                                HStack {
                                    Text("Refuel")
                                    Image(systemName: "microbe.circle.fill")
                                        .foregroundColor(.green)
                                }
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.top)
                                
                                ForEach(consumableProducts, id: \.id) { product in
                                    ProductView(
                                        product: product,
                                        isPurchasing: isPurchasing && purchasingProductID == product.id,
                                        buttonText: "Buy Now",
                                        action: { purchaseProduct(product) },
                                        customTitle: productInfo[product.id]?.title,
                                        customDescription: productInfo[product.id]?.description
                                    )
                                }
                            }
                        }
                        .padding(.bottom)
                        
                        // Legal links
                        VStack(spacing: 5) {
                            Link("Terms of Service", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                                .font(.footnote)
                                .foregroundColor(.blue)
                            
                            Link("Privacy Policy", destination: URL(string: "https://multiverseai.app/privacy-policy")!)
                                .font(.footnote)
                                .foregroundColor(.blue)
                        }
                        .padding(.top, 10)
                        .padding(.bottom, 20)
                    }
                }
            }
            .background(Color(.systemBackground).opacity(0.7))
            .cornerRadius(15)
            .padding()
        }
        .onAppear {
            loadProducts()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Your Credits", isPresented: $showCreditsPopup) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You have \(userCredits) credits available.")
        }
    }
    
    private var consumableProducts: [Product] {
        products.filter { $0.type == .consumable }
            .sorted { $0.price < $1.price }
    }
    
    private var subscriptionProducts: [Product] {
        products.filter { $0.type == .autoRenewable }
            .sorted { $0.price < $1.price }
    }
    
    private func loadProducts() {
        Task {
            do {
                // Product IDs from the storekit file
                let productIDs = [
                    // Consumables
                    "photons100",
                    "photons200",
                    "photons500",
                    "photons1200",
                    // Subscriptions
                    "premium"
                ]
                
                print("Attempting to fetch products with IDs: \(productIDs)")
                let products = try await Product.products(for: productIDs)
                print("Products fetched: \(products.count)")
                if products.isEmpty {
                    print("Warning: No products were returned from the App Store")
                } else {
                    for product in products {
                        print("Product loaded: \(product.id), \(product.displayName), \(product.displayPrice)")
                    }
                }
                await MainActor.run {
                    self.products = products
                } 
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load products: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func restorePurchases() {
        isRestoring = true
        
        Task {
            do {
                // Get the user ID
                let userID = UserManager.shared.getCurrentUserID()
                
                // Call the API to initialize/restore the user
                await NetworkService.shared.initializeUser(userID: userID)
                
                // Fetch user credits
                let credits = try await NetworkService.shared.fetchUserCredits(userID: userID)
                
                await MainActor.run {
                    isRestoring = false
                    userCredits = credits
                    showCreditsPopup = true
                }
            } catch {
                await MainActor.run {
                    isRestoring = false
                    errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func purchaseProduct(_ product: Product) {
        purchasingProductID = product.id
        isPurchasing = true
        
        Task {
            do {
                // Get user UUID from UserManager
                let userUUIDString = UserManager.shared.getCurrentUserID()
                let appAccountToken = UUID(uuidString: userUUIDString)
                let options: Set<Product.PurchaseOption> = appAccountToken != nil ? 
                    [.appAccountToken(appAccountToken!)] : []
                
                let result = try await product.purchase(options: options)
                
                switch result {
                case .success(let verification):
                    let transaction = try checkVerified(verification)
                    
                    // Finish the transaction
                    await transaction.finish()

                    NetworkService.shared.trackUserAction(
                        userID: UserManager.shared.getCurrentUserID(),
                        action: "make_purchase \(product.id)"
                    )
                    
                    
                    // Log purchase based on product ID and transaction details
                    print("Transaction completed - ID: \(transaction.id), productID: \(product.id), purchaseDate: \(transaction.purchaseDate), originalID: \(transaction.originalID), appAccountToken: \(transaction.appAccountToken?.uuidString ?? "nil"), expirationDate: \(transaction.expirationDate?.description ?? "nil"), offerID: \(transaction.offerID ?? "nil"), offerType: \(transaction.offerType?.rawValue ?? -1), environment: \(transaction.environment.rawValue), revocationDate: \(transaction.revocationDate?.description ?? "nil"), revocationReason: \(transaction.revocationReason?.rawValue ?? -1), ownershipType: \(transaction.ownershipType.rawValue), signed: \(transaction.isUpgraded)")
                    
                    // Determine credits based on product ID
                    var credits = 0
                    switch product.id {
                    case "photons100":
                        credits = 100
                    case "photons200":
                        credits = 200
                    case "photons500":
                        credits = 500
                    case "photons1200":
                        credits = 1200
                    default:
                        break
                    }
                    
                    // Call backend API to record one-time purchase
                    if credits > 0 {
                        let userID = UserManager.shared.getCurrentUserID()
                        do {
                            // Call API to add credits to user account
                            let updatedCredits = try await NetworkService.shared.oneTimePurchase(
                                userID: userID,
                                transactionID: String(transaction.id),
                                credits: credits
                            )
                            
                            await MainActor.run {
                                userCredits = updatedCredits
                                showCreditsPopup = true
                            }
                        } catch {
                            print("Failed to record purchase on backend: \(error.localizedDescription)")
                        }
                    }
                    
                    await MainActor.run {
                        isPurchasing = false
                        purchasingProductID = nil
                    }
                    
                case .userCancelled:
                    // Track cancelled purchase
                    NetworkService.shared.trackUserAction(
                        userID: UserManager.shared.getCurrentUserID(),
                        action: "cancel_purchase"
                    )
                    
                    await MainActor.run {
                        isPurchasing = false
                        purchasingProductID = nil
                    }
                    
                case .pending:
                    await MainActor.run {
                        isPurchasing = false
                        purchasingProductID = nil
                        // Inform the user that the purchase is pending
                    }
                    
                @unknown default:
                    await MainActor.run {
                        isPurchasing = false
                        purchasingProductID = nil
                        errorMessage = "Unknown purchase result"
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    purchasingProductID = nil
                    errorMessage = "Purchase failed: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        // Implement actual verification logic
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
}

// Reusable view for displaying a product
struct ProductView: View {
    let product: Product
    let isPurchasing: Bool
    let buttonText: String
    let action: () -> Void
    let customTitle: String?
    let customDescription: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(customTitle ?? product.displayName)
                Image(systemName: "microbe.circle.fill")
                    .foregroundColor(.green)
            }
            
            if let description = customDescription {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text(product.displayPrice)
                
                if product.type == .autoRenewable {
                    Text("/ month")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: action) {
                    Text(isPurchasing ? "Processing..." : buttonText)
                        .frame(minWidth: 120)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(isPurchasing)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// Custom error enum for store operations
enum StoreError: Error {
    case verificationFailed
}

// Preview provider for SwiftUI previews
#Preview {
    StoreView()
}
