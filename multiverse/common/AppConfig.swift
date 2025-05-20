import Foundation

// Base AppConfig class
class AppConfig {
    // Static instance to hold the current app configuration
    private static var current: MultiverseAppConfigurable?
    
    // Setup method to initialize the app configuration
    static func setup(with config: MultiverseAppConfigurable) {
        current = config
    }
    
    // Method to get the current app configuration
    static func getCurrent() -> MultiverseAppConfigurable? {
        return current
    }
}

// Multiverse App Configuration
class MultiverseAppConfig: MultiverseAppConfigurable {
    func configureApp() {
        // Configure settings specific to the main Multiverse app
        print("Configuring Multiverse App")
        // Additional app-specific configuration here
    }
}

// Multiverse Shopping App Configuration
class MultiverseShoppingAppConfig: MultiverseAppConfigurable {
    func configureApp() {
        // Configure settings specific to the Shopping app
        print("Configuring Multiverse Shopping App")
        // Additional app-specific configuration here
    }
} 