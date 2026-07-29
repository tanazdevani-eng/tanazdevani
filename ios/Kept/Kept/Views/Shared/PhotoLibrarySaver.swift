import UIKit
import Photos

/// Writes a captured photo out to the system Photos library — deliberately "add only," not
/// full read/write access, since Kept only ever wants to save a photo someone just took,
/// never browse or import from their existing library.
enum PhotoLibrarySaver {
    static func save(_ image: UIImage) async -> Bool {
        let status = await requestAddOnlyAuthorization()
        guard status == .authorized || status == .limited else { return false }
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, _ in
                continuation.resume(returning: success)
            }
        }
    }

    private static func requestAddOnlyAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }
}
