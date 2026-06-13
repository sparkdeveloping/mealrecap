import Foundation
import FirebaseStorage

final class PhotoStorageService: @unchecked Sendable {
    private let storage = Storage.storage()

    func uploadMealPhoto(uid: String, date: Date, mealId: String, jpegData: Data) async throws -> String {
        let dayID = FirestoreService.dayID(date)
        let path = "users/\(uid)/mealPhotos/\(dayID)/\(mealId).jpg"
        let ref = storage.reference(withPath: path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(jpegData, metadata: metadata)
        return path
    }
}
