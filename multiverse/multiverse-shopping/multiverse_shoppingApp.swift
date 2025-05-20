//
//  multiverse_shoppingApp.swift
//  multiverse-shopping
//
//  Created by biubiu on 5/19/25.
//

import SwiftUI
import SwiftData
import StoreKit

@main
struct multiverse_shoppingApp: App {
    // Initialize app at launch
    init() {
        // Set up app with the Shopping app configuration
        SharedAppBase.configure(with: MultiverseShoppingAppConfig())
        
        // Setup app lifecycle observation
        SharedAppBase.setupLifecycleObservers()
        
        // Setup StoreKit transaction listener
        SharedAppBase.setupTransactionListener()
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
            SharedAppBase.handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }
}
