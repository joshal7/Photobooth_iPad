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
    
    /// Captures a burst of images.
    /// Default implementation loops takePicture().
    func captureBurst(count: Int) async throws -> [String]
}

extension CameraService {
    func captureBurst(count: Int) async throws -> [String] {
        var results: [String] = []
        for _ in 0..<count {
            let urls = try await takePicture()
            results.append(contentsOf: urls)
            // Default small sleep to prevent overwhelming local camera
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return results
    }
}

enum CameraError: Error {
    case connectionFailed
    case invalidResponse
    case timeout
    case apiError(code: Int, message: String)
}
