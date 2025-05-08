import SwiftUI
import StoreKit
import Foundation

// StoreView for handling purchases and subscriptions
struct StoreView: View {
    @State private var products: [Product] = []
    @State private var isPurchasing = false
    @State private var purchasingProductID: String?
    @State private var errorMessage = ""
    @State private var showError = false
    
    var body: some View {
        VStack {
           Image(systemName: "storefront.circle.fill")
                .font(.largeTitle)
                .padding()
                .foregroundColor(.green)
            
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
                                    action: { purchaseProduct(product) }
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
                                    action: { purchaseProduct(product) }
                                )
                            }
                        }
                    }
                    .padding(.bottom)
                }
            }
        }
        .onAppear {
            loadProducts()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
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
                    
                    await MainActor.run {
                        isPurchasing = false
                        purchasingProductID = nil
                        // Here you could update the user's balance or subscription status
                    }
                    
                case .userCancelled:
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(product.displayName)
                Image(systemName: "microbe.circle.fill")
                                    .foregroundColor(.green)
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