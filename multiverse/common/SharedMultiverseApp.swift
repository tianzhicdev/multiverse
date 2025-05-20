import SwiftUI
import SwiftData
import StoreKit

// Protocol for app configurations
protocol MultiverseAppConfigurable {
    func configureApp()
}

// Base app functionality shared between apps
class SharedAppBase {
    // Configure the app with the specific app configuration
    static func configure(with appConfig: MultiverseAppConfigurable) {
        // Set up app configuration
        appConfig.configureApp()
        
        // This will trigger the UserManager singleton initialization
        _ = UserManager.shared
        
        // Setup iCloud synchronization notification
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { _ in
            // Sync iCloud changes
            NSUbiquitousKeyValueStore.default.synchronize()
        }
        
        // Track app open
        NetworkService.shared.trackUserAction(
            userID: UserManager.shared.getCurrentUserID(), 
            action: "app_open"
        )
    }
    
    // Listen for transaction updates from StoreKit
    static func setupTransactionListener() {
        // Start a task to handle transaction updates
        Task {
            print("🛍️ Started listening for StoreKit transactions")
            
            // Check for any previous transactions that haven't been processed
            await checkForUnfinishedTransactions()
            
            // Process transactions as they come in
            for await verification in StoreKit.Transaction.updates {
                print("🛍️ Received transaction update from StoreKit")
                do {
                    let transaction = try checkVerified(verification)
                    
                    print("🛍️ Transaction verified: \(transaction.productID), ID: \(transaction.id)")
                    
                    // Handle the transaction (unlock content, update UI, etc.)
                    await handleVerifiedTransaction(transaction)
                    
                    // Finish the transaction after handling it
                    await transaction.finish()
                    print("🛍️ Transaction finished for product: \(transaction.productID)")
                } catch {
                    // Handle verification errors
                    print("🛍️ Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    // Check for any transactions that haven't been finished yet
    static private func checkForUnfinishedTransactions() async {
        print("🛍️ Checking for unfinished transactions...")
        
        // Get all unfinished transactions
        for await verification in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(verification)
                
                print("🛍️ Found unfinished transaction: \(transaction.productID), ID: \(transaction.id)")
                
                // Process the transaction
                await handleVerifiedTransaction(transaction)
                
                // No need to finish these transactions
                print("🛍️ Processed unfinished transaction for product: \(transaction.productID)")
            } catch {
                print("🛍️ Unfinished transaction verification failed: \(error)")
            }
        }
    }
    
    // Verify the transaction
    static private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(let unverified, let error):
            print("🛍️ Unverified transaction: \(error.localizedDescription)")
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // Handle the verified transaction
    static private func handleVerifiedTransaction(_ transaction: StoreKit.Transaction) async {
        // Get the product ID from the transaction
        let productID = transaction.productID
        
        // Handle the transaction based on the product ID
        // This is where you'd update user entitlements, unlock features, etc.
        print("🛍️ Processing transaction for product: \(productID)")
        print("🛍️ Transaction details: ID \(transaction.id), purchased \(transaction.purchaseDate)")
        
        if transaction.environment == .sandbox {
            print("🛍️ This is a SANDBOX purchase")
        }
        
        // You might want to call a method in UserManager to update premium status
        // await UserManager.shared.updatePremiumStatus(for: productID)
    }
    
    // Define custom store errors
    enum StoreError: Error {
        case failedVerification
    }
    
    // Setup observers for app lifecycle events
    static func setupLifecycleObservers() {
        // Adding observers for app termination
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            AudioManager.shared.cleanup()
        }
    }
    
    // Handle scene phase changes
    static func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        if newPhase == .background {
            // App is entering background
            AudioManager.shared.stopLoadingSound()
        }
    }
} 