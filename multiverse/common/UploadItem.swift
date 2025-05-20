import Foundation
import SwiftData

@Model
final class UploadItem {
    var imageData: Data?
    var user_description: String
    var timestamp: Date
    var userID: String
    
    init(imageData: Data? = nil, user_description: String = "", timestamp: Date = Date(), userID: String = UserManager.shared.getCurrentUserID()) {
        self.imageData = imageData
        self.user_description = user_description
        self.timestamp = timestamp
        self.userID = userID
    }
} 