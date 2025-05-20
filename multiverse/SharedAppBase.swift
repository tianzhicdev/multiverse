import SwiftUI
import StoreKit

class SharedAppBase {
    // Configure app with specific configuration
    static func configure(with config: MultiverseAppConfigurable) {
        // Set up app configuration
        AppConfig.setup(with: config)
        
        // Execute the configuration
        config.configureApp()
    }
    
    // Setup lifecycle observers
    static func setupLifecycleObservers() {
        // Setup any app lifecycle observers here
        print("Setting up lifecycle observers for \(AppConfig.getAppName())")
    }
    
    // Setup StoreKit transaction listener
    static func setupTransactionListener() {
        // Setup StoreKit transaction listener
        print("Setting up transaction listener for \(AppConfig.getAppName())")
        
        Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    // Handle transaction
                    await transaction.finish()
                }
            }
        }
    }
    
    // Handle scene phase changes
    static func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            print("\(AppConfig.getAppName()) became active")
        case .inactive:
            print("\(AppConfig.getAppName()) became inactive")
        case .background:
            print("\(AppConfig.getAppName()) moved to background")
        @unknown default:
            print("Unknown scene phase change in \(AppConfig.getAppName())")
        }
    }
} 