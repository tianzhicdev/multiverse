import Foundation

class UserManager {
    // Key for storing the UUID in UserDefaults with iCloud sync
    private static let userUUIDKey = "com.multiverse.userUUID"
    // Key for storing terms acceptance status
    private static let termsAcceptedKey = "com.multiverse.termsAccepted"
    
    // Singleton instance
    static let shared = UserManager()
    
    // Private initializer for singleton pattern
    private init() {
        setupUserIdentifier()
    }
    
    // UUID for the current user
    private(set) var userIdentifier: String = ""
    
    // Setup user identifier (generate if it doesn't exist)
    private func setupUserIdentifier() {
        // Use NSUbiquitousKeyValueStore for iCloud sync
        let iCloudStore = NSUbiquitousKeyValueStore.default
        
        // Try to get the UUID from iCloud
        if let storedID = iCloudStore.string(forKey: UserManager.userUUIDKey) {
            userIdentifier = storedID
            print("Retrieved existing user ID from iCloud: \(storedID)")
        } else {
            // Generate a new UUID if one doesn't exist
            let newUUID = UUID().uuidString
            userIdentifier = newUUID
            
            // Save to iCloud
            iCloudStore.set(newUUID, forKey: UserManager.userUUIDKey)
            iCloudStore.synchronize()
            
            print("Generated new user ID and saved to iCloud: \(newUUID)")
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
        NSUbiquitousKeyValueStore.default.synchronize()
    }
    
    // Reset terms and conditions acceptance status for testing
    func resetTermsAcceptance() {
        NSUbiquitousKeyValueStore.default.set(false, forKey: UserManager.termsAcceptedKey)
        NSUbiquitousKeyValueStore.default.synchronize()
        print("Terms acceptance reset successfully")
    }

    // Clear user identifier for testing or account reset purposes
    func clearUserID() {
        // Remove from iCloud
        let iCloudStore = NSUbiquitousKeyValueStore.default
        iCloudStore.removeObject(forKey: UserManager.userUUIDKey)
        iCloudStore.synchronize()
        
        // Generate a new UUID
        let newUUID = UUID().uuidString
        userIdentifier = newUUID
        
        // Save the new UUID to iCloud
        iCloudStore.set(newUUID, forKey: UserManager.userUUIDKey)
        iCloudStore.synchronize()
        
        print("User ID cleared and reset to: \(newUUID)")
        
        // Re-initialize user on the backend
        Task {
            await NetworkService.shared.initializeUser(userID: userIdentifier)
        }
    }
} 