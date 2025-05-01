import SwiftUI
import UIKit

struct FullImageView: View {
    let uiImage: UIImage
    let themeName: String
    let resultImageID: String
    let onCreditsUpdated: ((Int) -> Void)?
    
    // Environment dismiss to close the sheet
    @Environment(\.dismiss) private var dismiss
    
    // Alert states for download flow
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccessAlert = false
    @State private var successMessage = ""
    
    @State private var opacity = 0.0
    @State private var scale = 0.8
    @State private var rotation = 0.0
    @State private var showFireworks = false
    
    // Custom initializer so callers can optionally provide the credits callback
    init(uiImage: UIImage, themeName: String, resultImageID: String, onCreditsUpdated: ((Int) -> Void)? = nil) {
        self.uiImage = uiImage
        self.themeName = themeName
        self.resultImageID = resultImageID
        self.onCreditsUpdated = onCreditsUpdated
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Credits bar
                CreditsBarView()

                ZStack {
                    // The image
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(opacity)
                        .scaleEffect(scale)
                        .rotationEffect(.degrees(rotation))
                        .onAppear {
                            // Reveal the image with rotation immediately
                            withAnimation(.easeInOut(duration: 0.5)) {
                                opacity = 1.0
                                scale = 1.1
                                rotation = 5
                            }

                            // Settle the image with spring animation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    scale = 1.0
                                    rotation = 0
                                }
                            }

                            // Show fireworks celebration after image is revealed
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                showFireworks = true
                            }
                        }

                    if showFireworks {
                        FireworksView()
                    }

                    // Theme name overlay at the bottom
                    VStack {
                        Spacer()
                        Text(themeName)
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                            .padding(.bottom, 40)
                    }
                }

                // Download and Close buttons
                HStack(spacing: 20) {
                    Button {
                        downloadImage()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.square.fill")
                            Text("10")
                            Image(systemName: "microbe.circle.fill")
                        }
                        .padding(8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }

                    Button("Close") {
                        dismiss()
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.4))
                    .cornerRadius(8)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text(successMessage)
        }
    }

    // MARK: - Download Logic
    private func downloadImage() {
        // Check credits before attempting download
        Task {
            do {
                let userID = UserManager.shared.getCurrentUserID()

                // First check if user has enough credits
                let currentCredits = try await NetworkService.shared.fetchUserCredits(
                    userID: userID
                )

                if currentCredits < 10 {
                    await MainActor.run {
                        errorMessage = "Insufficient credits. Each download costs 10 credits."
                        showError = true
                    }
                    return
                }

                // Try to deduct 10 credits
                let remainingCredits = try await NetworkService.shared.useCredits(
                    userID: userID,
                    credits: 10
                )

                // Credits deducted successfully, save the image
                await MainActor.run {
                    UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
                    // Show success alert
                    successMessage = "Image saved successfully! You have \(remainingCredits) credits remaining."
                    showSuccessAlert = true
                    // Notify parent about credit update
                    onCreditsUpdated?(remainingCredits)
                }

                // Track the download action (non-blocking)
                NetworkService.shared.trackUserAction(
                    userID: userID,
                    action: "download",
                    imageID: resultImageID
                )
            } catch {
                print("Failed to download image: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = "Download failed: Insufficient credits. Each download costs 10 credits."
                    showError = true
                }
            }
        }
    }
} 