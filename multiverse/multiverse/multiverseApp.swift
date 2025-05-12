//
//  multiverseApp.swift
//  multiverse
//
//  Created by biubiu on 4/19/25.
//

import SwiftUI
import SwiftData
import StoreKit

@main
struct multiverseApp: App {
    // Initialize UserManager at app launch
    init() {
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
        
        // Setup app lifecycle observation
        setupLifecycleObservers()
        
        // Setup StoreKit transaction listener
        setupTransactionListener()
    }
    
    // Listen for transaction updates from StoreKit
    private func setupTransactionListener() {
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
    private func checkForUnfinishedTransactions() async {
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
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(let unverified, let error):
            print("🛍️ Unverified transaction: \(error.localizedDescription)")
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // Handle the verified transaction
    private func handleVerifiedTransaction(_ transaction: StoreKit.Transaction) async {
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
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UploadItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @Environment(\.scenePhase) private var scenePhase
    
    // State to control splash screen visibility
    @State private var showSplashScreen = true
    
    // State to control terms and conditions visibility
    @State private var showTermsAndConditions = false
    
    // Setup observers for app lifecycle events
    private func setupLifecycleObservers() {
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
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        if newPhase == .background {
            // App is entering background
            AudioManager.shared.stopLoadingSound()
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplashScreen {
                    SplashScreenView()
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    showSplashScreen = false
                                    // Check if user has accepted terms
                                    showTermsAndConditions = !UserManager.shared.hasAcceptedTerms()
                                }
                            }
                        }
                } else {
                    LandingView()
                        .fullScreenCover(isPresented: $showTermsAndConditions) {
                            TermsAndConditionsView(isPresented: $showTermsAndConditions)
                        }
                }
            }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }
}
