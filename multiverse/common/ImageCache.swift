import Foundation
import UIKit

/// A lightweight in-memory cache for image `Data` objects keyed by their `resultImageID`.
///
/// The cache lives for the lifetime of the application process. It is **not** persisted to disk –
/// it only serves to prevent additional network round-trips while the user navigates between
/// screens within the same session. The cache is automatically cleared whenever the user performs
/// an explicit re-roll / re-split action so that new images are fetched freshly.
final class ImageCache {
    // MARK: - Singleton
    static let shared = ImageCache()
    private init() {}

    // MARK: - Backing store
    private let cache = NSCache<NSString, NSData>()

    /// Retrieves cached image data for the supplied `resultImageID` if present.
    func imageData(for resultImageID: String) -> Data? {
        cache.object(forKey: resultImageID as NSString) as Data?
    }

    /// Stores `data` in the cache under `resultImageID`.
    func setImageData(_ data: Data, for resultImageID: String) {
        cache.setObject(data as NSData, forKey: resultImageID as NSString)
    }

    /// Clears the entire cache. Used when the user re-splits or re-rolls images so that
    /// stale images are not displayed.
    func clearAll() {
        cache.removeAllObjects()
    }
} 