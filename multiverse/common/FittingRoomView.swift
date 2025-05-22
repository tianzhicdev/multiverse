import SwiftUI
import PhotosUI

struct FittingRoomView: View {
    // State for person image
    @State private var selectedPersonImage: PhotosPickerItem?
    @State private var personImageData: Data?
    
    // State for clothing image
    @State private var selectedClothImage: PhotosPickerItem?
    @State private var clothImageData: Data?
    
    // State for cloth type selection
    @State private var selectedClothType = "upper_body"
    private let clothTypeOptions = ["upper_body", "lower_body", "dress"]
    
    // State for processing status
    @State private var isProcessing = false
    @State private var resultImage: UIImage?
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Person image picker
                    VStack(alignment: .leading) {
                        Text("Select Person Image")
                            .font(.headline)
                        
                        PhotosPicker(selection: $selectedPersonImage, matching: .images) {
                            if let personImageData = personImageData,
                               let uiImage = UIImage(data: personImageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 200)
                                    .cornerRadius(8)
                            } else {
                                Label("Select Person Image", systemImage: "person")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 200)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                        .onChange(of: selectedPersonImage) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    personImageData = data
                                }
                            }
                        }
                    }
                    
                    // Clothing image picker
                    VStack(alignment: .leading) {
                        Text("Select Clothing Image")
                            .font(.headline)
                        
                        PhotosPicker(selection: $selectedClothImage, matching: .images) {
                            if let clothImageData = clothImageData,
                               let uiImage = UIImage(data: clothImageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 200)
                                    .cornerRadius(8)
                            } else {
                                Label("Select Clothing Image", systemImage: "tshirt")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 200)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                        .onChange(of: selectedClothImage) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    clothImageData = data
                                }
                            }
                        }
                    }
                    
                    // Cloth type picker
                    VStack(alignment: .leading) {
                        Text("Select Clothing Type")
                            .font(.headline)
                        
                        Picker("Clothing Type", selection: $selectedClothType) {
                            ForEach(clothTypeOptions, id: \.self) { option in
                                Text(option.replacingOccurrences(of: "_", with: " ").capitalized)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // Submit button
                    Button(action: {
                        submitImages()
                    }) {
                        if isProcessing {
                            HStack {
                                Text("Processing")
                                ProgressView()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        } else {
                            Text("Try It On")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .disabled(isProcessing || personImageData == nil || clothImageData == nil)
                    
                    // Result image display
                    if let resultImage = resultImage {
                        VStack(alignment: .leading) {
                            Text("Result")
                                .font(.headline)
                            
                            Image(uiImage: resultImage)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Virtual Fitting Room")
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func submitImages() {
        guard let personData = personImageData, let clothData = clothImageData else {
            errorMessage = "Please select both person and clothing images"
            showError = true
            return
        }
        
        // Process images
        isProcessing = true
        
        Task {
            do {
                let result = try await NetworkService.shared.applyFashion(
                    personImage: personData,
                    clothImage: clothData,
                    type: selectedClothType,
                    userID: UserManager.shared.getCurrentUserID()
                )
                
                await MainActor.run {
                    if let processedImage = UIImage(data: result) {
                        resultImage = processedImage
                    } else {
                        errorMessage = "Failed to process the result image"
                        showError = true
                    }
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to process images: \(error.localizedDescription)"
                    showError = true
                    isProcessing = false
                }
            }
        }
    }
}

#Preview {
    FittingRoomView()
} 