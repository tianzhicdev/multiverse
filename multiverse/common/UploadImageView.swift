import SwiftUI
import PhotosUI

struct UploadImageView: View {
    // Binding for the selected image data
    @Binding var imageData: Data?
    
    // Binding for the uploaded image ID
    @Binding var imageID: String?
    
    // Optional placeholder text
    var placeholder: String
    
    // Optional image height
    var imageHeight: CGFloat
    
    // Image opacity after selection
    var imageOpacity: Double
    
    // States for uploading process
    @Binding var isUploading: Bool
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Camera availability state
    @State private var isCameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
    
    // Show source selection popup
    @State private var showSourceSelection = false
    
    // Initialize with default values
    init(
        imageData: Binding<Data?>,
        imageID: Binding<String?>,
        placeholder: String = "Select Image",
        imageHeight: CGFloat = 200,
        imageOpacity: Double = 1.0,
        isUploading: Binding<Bool> = .constant(false)
    ) {
        self._imageData = imageData
        self._imageID = imageID
        self._isUploading = isUploading
        self.placeholder = placeholder
        self.imageHeight = imageHeight
        self.imageOpacity = imageOpacity
    }
    
    var body: some View {
        VStack {
            // Image display area
            if let imageData = imageData, 
               let uiImage = UIImage(data: imageData) {
                // If an image is selected, display it
                ZStack {
                    Color.clear
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .aspectRatio(contentMode: .fill)
                        .opacity(imageOpacity)
                }
                .frame(maxWidth: .infinity)
                .frame(height: imageHeight)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.green, lineWidth: 1)
                )
                .onTapGesture {
                    showSourceSelection = true
                }
            } else {
                // If no image is selected, show a placeholder
                Image(systemName: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .frame(height: imageHeight)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.green, lineWidth: 1)
                    )
                    .onTapGesture {
                        showSourceSelection = true
                    }
            }
        }
        .confirmationDialog("Select Image Source", isPresented: $showSourceSelection) {
            Button("Photo Library") {
                selectedItem = nil  // Reset before showing picker
                isShowingPhotoPicker = true
            }
            
            if isCameraAvailable {
                Button("Camera") {
                    isShowingCamera = true
                }
            }
            
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraView(imageData: $imageData, onCapture: uploadImage)
        }
        .photosPicker(isPresented: $isShowingPhotoPicker,
                      selection: $selectedItem,
                      matching: .images)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: selectedItem) { newItem in
            if let item = newItem {
                handleSelectedItem()
            }
        }
    }
    
    // MARK: - Private Properties
    
    // Selected photo item
    @State private var selectedItem: PhotosPickerItem?
    
    // Camera view state
    @State private var isShowingCamera = false
    @State private var isShowingPhotoPicker = false
    
    // MARK: - Private Methods
    
    private func handleSelectedItem() {
        guard let item = selectedItem else { return }
        
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    self.imageData = data
                }
                uploadImage()
            }
        }
    }
    
    private func uploadImage() {
        guard let data = imageData else { return }
        
        Task {
            await MainActor.run {
                isUploading = true
            }
            
            do {
                // Preprocess image
                guard let processedData = ImagePreprocessor.preprocessImage(data) else {
                    throw NSError(domain: "ImageProcessingError", 
                                code: -1, 
                                userInfo: [NSLocalizedDescriptionKey: "Failed to preprocess image"])
                }
                
                // Upload image
                let uploadedID = try await NetworkService.shared.uploadImage(
                    imageData: processedData,
                    userID: UserManager.shared.getCurrentUserID()
                )
                
                await MainActor.run {
                    imageID = uploadedID
                    isUploading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to upload image: \(error.localizedDescription)"
                    showError = true
                    isUploading = false
                }
            }
        }
    }
}

// Camera view for taking photos
struct CameraView: UIViewControllerRepresentable {
    @Binding var imageData: Data?
    var onCapture: () -> Void
    
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.imageData = image.jpegData(compressionQuality: 0.8)
                parent.onCapture()
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
} 