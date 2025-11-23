import Foundation
import Combine
import UIKit

class SonyCameraClient: CameraService {
    @Published var isConnected: Bool = false
    var connectionStatus: AnyPublisher<Bool, Never> {
        $isConnected.eraseToAnyPublisher()
    }
    
    var previewStream: AnyPublisher<UIImage?, Never> {
        streamer.$currentFrame.eraseToAnyPublisher()
    }
    
    private let session: URLSession
    private let config: ConfigManager
    private let streamer = MJPEGStreamer()
    
    init(config: ConfigManager = .shared) {
        self.config = config
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15.0 // Increased to handle capture delays
        self.session = URLSession(configuration: configuration)
    }
    
    func connect() async throws {
        // 1. Check handshake (startRecMode)
        let endpoint = "\(config.cameraEndpoint)/camera"
        
        do {
            _ = try await sendRPC(method: "startRecMode", params: [], to: endpoint)
            
            // 2. Set Postview Image Size to 2M for faster transfer
            // This reduces transfer time significantly (from ~5s to <1s)
            try? await setPostviewImageSize("2M")
            
            DispatchQueue.main.async { self.isConnected = true }
        } catch let error as CameraError {
            if case .apiError(let code, _) = error, code == 40402 {
                // Already in Rec Mode, consider connected
                DispatchQueue.main.async { self.isConnected = true }
                return
            }
            DispatchQueue.main.async { self.isConnected = false }
            throw error
        } catch let error as URLError {
            DispatchQueue.main.async { self.isConnected = false }
            if error.code == .timedOut || error.code == .cannotConnectToHost {
                 throw CameraError.apiError(code: -1, message: "Connection timed out. Please ensure your iPad is connected to the Camera's Wi-Fi (e.g., DIRECT-xxxx:Sony).")
            }
            throw error
        } catch {
            DispatchQueue.main.async { self.isConnected = false }
            throw error
        }
    }
    
    func startLiveView() async throws {
        let endpoint = "\(config.cameraEndpoint)/camera"
        let response = try await sendRPC(method: "startLiveview", params: [], to: endpoint)
        
        guard let result = response["result"] as? [Any],
              let urlString = result.first as? String,
              let url = URL(string: urlString) else {
            throw CameraError.invalidResponse
        }
        
        // Start the internal streamer
        DispatchQueue.main.async {
            self.streamer.start(url: url)
        }
    }
    
    func stopLiveView() {
        streamer.stop()
    }
    
    func takePicture() async throws -> [String] {
        let endpoint = "\(config.cameraEndpoint)/camera"
        // actTakePicture returns a URL array
        let response = try await sendRPC(method: "actTakePicture", params: [], to: endpoint)
        
        guard let result = response["result"] as? [Any],
              let urlArray = result.first as? [String] else {
            throw CameraError.invalidResponse
        }
        return urlArray
    }
    
    private func setPostviewImageSize(_ size: String) async throws {
        let endpoint = "\(config.cameraEndpoint)/camera"
        // "Original", "2M", "VGA" are common values. We use "2M".
        _ = try await sendRPC(method: "setPostviewImageSize", params: [size], to: endpoint)
    }
    
    func fetchImage(url: String) async throws -> Data {
        guard let imageURL = URL(string: url) else {
            throw CameraError.invalidResponse
        }
        
        let (data, _) = try await session.data(from: imageURL)
        return data
    }
    
    func checkConnection() async -> Bool {
        let endpoint = "\(config.cameraEndpoint)/camera"
        // Use getEvent with longpolling=false for a quick check
        do {
            _ = try await sendRPC(method: "getEvent", params: [false], to: endpoint)
            return true
        } catch {
            print("Heartbeat failed: \(error)")
            return false
        }
    }
    
    // MARK: - JSON-RPC Helper
    
    private func sendRPC(method: String, params: [Any], to urlString: String) async throws -> [String: Any] {
        guard let url = URL(string: urlString) else {
            throw CameraError.connectionFailed
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "method": method,
            "params": params,
            "id": 1,
            "version": "1.0"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CameraError.connectionFailed
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CameraError.invalidResponse
        }
        
        if let error = json["error"] as? [Any], let code = error.first as? Int, let message = error.last as? String {
            throw CameraError.apiError(code: code, message: message)
        }
        
        return json
    }
}
