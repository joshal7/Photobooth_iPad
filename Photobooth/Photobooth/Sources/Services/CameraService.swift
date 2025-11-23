import UIKit
import Combine

protocol CameraService {
    var isConnected: Bool { get }
    var connectionStatus: AnyPublisher<Bool, Never> { get }
    var previewStream: AnyPublisher<UIImage?, Never> { get }
    
    func connect() async throws
    func startLiveView() async throws
    func stopLiveView()
    func takePicture() async throws -> [String] // Returns array of image URLs (or local paths)
    func fetchImage(url: String) async throws -> Data
    
    /// Checks if the connection to the camera is still active.
    /// Returns true if connected, false otherwise.
    func checkConnection() async -> Bool
}

enum CameraError: Error {
    case connectionFailed
    case invalidResponse
    case timeout
    case apiError(code: Int, message: String)
}
