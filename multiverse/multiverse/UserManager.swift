import Foundation

class UserManager {
    // Key for storing the UUID in UserDefaults with iCloud sync
    private static let userUUIDKey = "com.multiverse.userUUID"
    
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
    }
    
    // Method to retrieve the current user ID
    func getCurrentUserID() -> String {
        return userIdentifier
    }
} 