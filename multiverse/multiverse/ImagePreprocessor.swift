import UIKit
import CoreGraphics
import ImageIO

class ImagePreprocessor {
    static func preprocessImage(_ imageData: Data) -> Data? {
        guard let uiImage = UIImage(data: imageData) else {
            return nil
        }
        
        // Log original image information
        print("Original image: \(uiImage.size.width)x\(uiImage.size.height) pixels, \(imageData.count) bytes")
        if let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
           let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {
            // Get the UTType of the image
            if let uti = CGImageSourceGetType(imageSource) {
                print("Original format: \(uti as String)")
            }
        }
        
        // Resize image if needed
        let resizedImage = resizeImage(uiImage, maxDimension: 1024)
        
        // Convert to JPEG
        let processedData = convertToJPEG(resizedImage)
        
        // Log processed image information
        if let processedData = processedData {
            print("Processed image: \(resizedImage.size.width)x\(resizedImage.size.height) pixels, \(processedData.count) bytes, format: JPEG")
        }
        
        return processedData
    }
    
    private static func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let width = image.size.width
        let height = image.size.height
        
        // Calculate the scale factor
        let scale = min(maxDimension / width, maxDimension / height)
        
        // If image is already smaller than max dimension, return original
        if scale >= 1.0 {
            return image
        }
        
        // Calculate new size
        let newSize = CGSize(width: width * scale, height: height * scale)
        
        // Create new image context
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? image
    }
    
    private static func convertToJPEG(_ image: UIImage) -> Data? {
        return image.jpegData(compressionQuality: 0.6)
    }
} 
