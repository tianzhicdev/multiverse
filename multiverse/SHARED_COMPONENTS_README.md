# Multiverse Apps Shared Components Guide

This document explains how the shared components and configurations are structured across the Multiverse apps.

## Project Structure

The project consists of two main applications:
- **multiverse**: The main Multiverse app
- **multiverse-shopping**: The Multiverse Shopping app

Both apps share common components and use app-specific configurations.

## Shared Components

All shared components are located in the `common` directory. These include:
- UI components (BoxView, HeaderView, etc.)
- Services (NetworkService, AudioManager, etc.)
- Models (Item, UploadItem, etc.)

## App Configuration

Each app has its own app-specific configuration that can be accessed throughout the entire app.

### How to Use App Config

1. **Accessing Configuration Values**

```swift
// Get the app name
let appName = AppConfig.current.appName

// Check if a feature is enabled
if AppConfig.current.enabledFeatures.contains("image_generation") {
    // Enable image generation UI
}

// Use app-specific colors
myView.backgroundColor = AppConfig.current.primaryColor
```

2. **Adding New Configuration Values**

If you need to add new configuration values:

1. Add the property to the `AppConfigProvider` protocol in `AppConfig.swift`
2. Implement the property in the `BaseAppConfig` class
3. Override the property in app-specific configurations as needed

```swift
// Add to AppConfigProvider protocol
var newFeatureEnabled: Bool { get }

// Implement in BaseAppConfig
public var newFeatureEnabled: Bool { false }

// Override in app-specific configs
public override var newFeatureEnabled: Bool { true }
```

## Building and Running the Apps

Both apps should be built and archived separately but will share the same codebase for common functionality.

1. Open the Xcode project
2. Select the target app (multiverse or multiverse-shopping)
3. Build and run

## Adding New Features

When adding new features:

1. Place shared code in the `common` directory
2. Use `AppConfig.current` to access app-specific configuration
3. Conditionally enable/disable features based on the app configuration

Example:
```swift
if AppConfig.current.appType == .multiverseShopping {
    // Show shopping-specific UI
} else {
    // Show regular multiverse UI
}
```

## Troubleshooting

If you encounter issues:

1. Make sure both apps have the required entitlements
2. Check that app-specific configurations are set up correctly
3. Ensure that shared components don't have app-specific code outside of conditional statements 