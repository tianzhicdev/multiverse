import Foundation
import os.log

// Define the missing NSUbiquitousKeyValueStoreChangeReason enum
enum NSUbiquitousKeyValueStoreChangeReason: Int {
    case serverChange = 0
    case initialSyncChange = 1
    case quotaViolationChange = 2
    case accountChange = 3
    
    var description: String {
        switch self {
        case .serverChange:
            return "Server Change"
        case .initialSyncChange:
            return "Initial Sync"
        case .quotaViolationChange:
            return "Quota Violation"
        case .accountChange:
            return "Account Change"
        @unknown default:
            return "Unknown Change (\(self.rawValue))"
        }
    }
}

class UserManager {
    // Key for storing the UUID in iCloud KVS
    private static let userUUIDKey = "com.multiverse.userUUID"
    // Key for storing terms acceptance status
    private static let termsAcceptedKey = "com.multiverse.termsAccepted"
    
    // Singleton instance
    static let shared = UserManager()
    
    // Logger
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.multiverse", category: "UserManager")
    
    // Private initializer for singleton pattern
    private init() {
        // Initialize iCloud key-value store synchronization
        initializeICloudSync()
        setupUserIdentifier()
    }
    
    // UUID for the current user
    private(set) var userIdentifier: String = ""
    
    private func initializeICloudSync() {
        // Register for iCloud KVS change notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ubiquitousKeyValueStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )
        
        // Force initial synchronization with iCloud
        let success = NSUbiquitousKeyValueStore.default.synchronize()
        if !success {
            logger.error("Failed to synchronize with iCloud KVS")
        } else {
            logger.info("Successfully synchronized with iCloud KVS")
        }
    }
    
    @objc private func ubiquitousKeyValueStoreDidChange(_ notification: Notification) {
        if let reasonValue = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int,
           let reason = NSUbiquitousKeyValueStoreChangeReason(rawValue: reasonValue) {
            
            logger.info("iCloud KVS changed: \(reason.description)")
            
            if let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
                for key in changedKeys {
                    if key == UserManager.userUUIDKey {
                        if let newID = NSUbiquitousKeyValueStore.default.string(forKey: key) {
                            userIdentifier = newID
                            logger.info("Updated user identifier from iCloud: \(newID)")
                        }
                    }
                }
            }
        }
    }
    
    // Setup user identifier (generate if it doesn't exist)
    private func setupUserIdentifier() {
        let iCloudStore = NSUbiquitousKeyValueStore.default
        
        // Try to get the UUID from iCloud
        if let storedID = iCloudStore.string(forKey: UserManager.userUUIDKey) {
            userIdentifier = storedID
            logger.info("Retrieved existing user ID from iCloud: \(storedID)")
        } else {
            // Generate a new UUID if one doesn't exist
            let newUUID = UUID().uuidString
            userIdentifier = newUUID
            
            // Save to iCloud
            iCloudStore.set(newUUID, forKey: UserManager.userUUIDKey)
            let syncSuccess = iCloudStore.synchronize()
            
            if syncSuccess {
                logger.info("Generated new user ID and saved to iCloud: \(newUUID)")
            } else {
                logger.error("Generated new user ID but failed to save to iCloud: \(newUUID)")
            }
        }
        
        // Initialize user on the backend
        Task {
            await NetworkService.shared.initializeUser(userID: userIdentifier)
        }
    }
    
    // Method to retrieve the current user ID
    func getCurrentUserID() -> String {
        return userIdentifier
    }
    
    // Check if user has accepted terms and conditions
    func hasAcceptedTerms() -> Bool {
        return NSUbiquitousKeyValueStore.default.bool(forKey: UserManager.termsAcceptedKey)
    }
    
    // Mark terms and conditions as accepted
    func acceptTerms() {
        NSUbiquitousKeyValueStore.default.set(true, forKey: UserManager.termsAcceptedKey)
        let success = NSUbiquitousKeyValueStore.default.synchronize()
        if success {
            logger.info("Terms acceptance set to true and successfully synchronized")
        } else {
            logger.error("Terms acceptance set to true but failed to synchronize")
        }
    }
    
    // Reset terms and conditions acceptance status for testing
    func resetTermsAcceptance() {
        NSUbiquitousKeyValueStore.default.set(false, forKey: UserManager.termsAcceptedKey)
        let success = NSUbiquitousKeyValueStore.default.synchronize()
        if success {
            logger.info("Terms acceptance reset successfully")
        } else {
            logger.error("Failed to reset terms acceptance")
        }
    }

    // Clear user identifier for testing or account reset purposes
    func clearUserID() {
        let iCloudStore = NSUbiquitousKeyValueStore.default
        
        // Remove from iCloud
        iCloudStore.removeObject(forKey: UserManager.userUUIDKey)
        let removeSuccess = iCloudStore.synchronize()
        
        // Generate a new UUID
        let newUUID = UUID().uuidString
        userIdentifier = newUUID
        
        // Save the new UUID to iCloud
        iCloudStore.set(newUUID, forKey: UserManager.userUUIDKey)
        let saveSuccess = iCloudStore.synchronize()
        
        if removeSuccess && saveSuccess {
            logger.info("User ID cleared and reset to: \(newUUID)")
        } else {
            logger.error("Issues occurred while clearing/resetting user ID")
        }
        
        // Re-initialize user on the backend
        Task {
            await NetworkService.shared.initializeUser(userID: userIdentifier)
        }
    }
} 