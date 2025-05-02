//
//  multiverseApp.swift
//  multiverse
//
//  Created by biubiu on 4/19/25.
//

import SwiftUI
import SwiftData

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

    var body: some Scene {
        WindowGroup {
            LandingView()
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }
    
    @Environment(\.scenePhase) private var scenePhase
    
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
}
