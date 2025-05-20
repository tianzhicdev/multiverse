import Foundation

// Protocol for app configuration with app_name property
protocol MultiverseAppConfigurable {
    func configureApp()
    var appName: String { get }
}

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
    
    // Helper method to get app name
    static func getAppName() -> String {
        return current?.appName ?? "multiverse"
    }
}

// Multiverse App Configuration
class MultiverseAppConfig: MultiverseAppConfigurable {
    let appName: String = "multiverse"
    
    func configureApp() {
        // Configure settings specific to the main Multiverse app
        print("Configuring Multiverse App")
        // Additional app-specific configuration here
    }
}

// Multiverse Shopping App Configuration
class MultiverseShoppingAppConfig: MultiverseAppConfigurable {
    let appName: String = "multiverse_shopping"
    
    func configureApp() {
        // Configure settings specific to the Shopping app
        print("Configuring Multiverse Shopping App")
        // Additional app-specific configuration here
    }
} 