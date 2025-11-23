import Foundation
import Combine
import SwiftUI
import Photos

enum AppState: Equatable {
    case initialization
    case idle
    case capture(count: Int)
    case review(images: [String], index: Int)
    case error(message: String)
    case wifiMismatch(targetSSID: String)
}

@MainActor
class StateMachine: ObservableObject {
    @Published var state: AppState = .initialization
    @Published var previewImage: UIImage?
    @Published var capturedImages: [String] = []
    @Published var countdown: Int = 0
    @Published var isFlashing: Bool = false
    @Published var showGuidance: Bool = false
    
    private var cameraService: CameraService
    private let config: ConfigManager
    private var cancellables = Set<AnyCancellable>()
    private var heartbeatTimer: Timer?
    private var bypassWifiCheck: Bool = false
    
    init() {
        self.config = ConfigManager.shared
        
        // Initialize service based on config
        if config.useLocalCamera {
            self.cameraService = LocalCameraClient()
        } else {
            self.cameraService = SonyCameraClient(config: config)
        }
        
        setupBindings()
        setupHeartbeat()
    }
    
    private func setupBindings() {
        // Listen for config changes to switch camera service
        config.$useLocalCamera
            .dropFirst()
            .sink { [weak self] useLocal in
                Task { @MainActor [weak self] in
                    self?.switchCameraService(useLocal: useLocal)
                }
            }
            .store(in: &cancellables)
            
        bindPreviewStream()
    }
    
    private func bindPreviewStream() {
        // Subscribe to the current service's preview stream
        cameraService.previewStream
            .receive(on: DispatchQueue.main)
            .assign(to: \.previewImage, on: self)
            .store(in: &cancellables)
    }
    
    private func switchCameraService(useLocal: Bool) {
        // Stop current service
        cameraService.stopLiveView()
        
        // Switch service
        if useLocal {
            self.cameraService = LocalCameraClient()
            // Disconnect from camera Wi-Fi to allow fallback to home Wi-Fi
            WifiManager.shared.disconnectFromCameraWifi(ssid: config.cameraSSID)
        } else {
            self.cameraService = SonyCameraClient(config: config)
            // Auto-connect to camera Wi-Fi
            Task {
                try? await WifiManager.shared.connectToCameraWifi(ssid: config.cameraSSID, password: config.cameraPassword)
            }
        }
        
        // Re-bind stream
        bindPreviewStream()
        
        // Reset bypass flag to enforce checks
        bypassWifiCheck = false
        
        // Re-initialize
        transition(to: .initialization)
    }
    
    func start() {
        transition(to: .initialization)
    }
    
    func transition(to newState: AppState) {
        print("Transitioning to: \(newState)")
        self.state = newState
        
        switch newState {
        case .initialization:
            Task { await initializeCamera() }
            
        case .idle:
            Task { await startLiveView() }
            
        case .capture:
            Task { await startCaptureSequence() }
            
        case .review(let images, _):
            if images.isEmpty {
                transition(to: .idle)
            } else {
                Task { await startReviewSequence() }
            }
            
        case .error:
            break
            
        case .wifiMismatch(let targetSSID):
            Task { await monitorWifiConnection(targetSSID: targetSSID) }
        }
    }
    
    // MARK: - Actions
    
    private func initializeCamera() async {
        // If using external camera, check Wi-Fi first
        if !config.useLocalCamera && !bypassWifiCheck {
            let currentSSID = await WifiManager.shared.getCurrentSSID()
            
            // Strict check: If SSID is nil (unknown) OR doesn't match, show prompt.
            // This avoids the long timeout if we are not connected.
            if currentSSID != config.cameraSSID {
                print("Wi-Fi Mismatch: Current: \(String(describing: currentSSID)), Target: \(config.cameraSSID)")
                transition(to: .wifiMismatch(targetSSID: config.cameraSSID))
                return
            }
        }
        
        // Reset bypass flag for next time
        bypassWifiCheck = false

        do {
            try await cameraService.connect()
            await startLiveView()
            transition(to: .idle)
        } catch {
            // If connection fails and we are external, maybe we are on wrong wifi?
            if !config.useLocalCamera {
                 transition(to: .wifiMismatch(targetSSID: config.cameraSSID))
            } else {
                transition(to: .error(message: "Failed to connect to camera: \(error.localizedDescription)"))
            }
        }
    }
    
    func forceConnection() {
        bypassWifiCheck = true
        transition(to: .initialization)
    }
    
    private func monitorWifiConnection(targetSSID: String) async {
        while case .wifiMismatch = state {
            // 1. Check SSID (Fastest)
            let currentSSID = await WifiManager.shared.getCurrentSSID()
            if currentSSID == targetSSID {
                print("SSID Matched: \(targetSSID)")
                transition(to: .initialization)
                return
            }
            
            // 2. Probe Camera (Robust fallback)
            // Even if SSID is nil or wrong (e.g. permission issue), try to reach the camera.
            // We use a short timeout to avoid blocking.
            if await probeCameraConnection() {
                print("Camera Probe Successful! Force connecting...")
                forceConnection()
                return
            }
            
            // Poll every 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
    }
    
    private func probeCameraConnection() async -> Bool {
        // Construct a simple URL to check reachability.
        // Sony cameras usually have a DD.xml or similar, but checking the root or /sony might work.
        // We'll try the endpoint URL.
        guard let url = URL(string: config.cameraEndpoint) else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 1.0 // Short timeout for probing
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if response is HTTPURLResponse {
                // If we get ANY response (even 404 or 500), it means the device is reachable.
                // Sony cameras might return 200 or 403/404 depending on the path.
                return true
            }
        } catch {
            // Ignore errors
        }
        return false
    }
    
    private func startLiveView() async {
        do {
            try await cameraService.startLiveView()
        } catch {
            print("Failed to start live view: \(error)")
        }
    }
    
    func triggerCapture() {
        guard case .idle = state else { return }
        transition(to: .capture(count: 0))
    }
    

    private func startCaptureSequence() async {
        capturedImages.removeAll()
        
        let totalPhotos = config.photoCount
        var previousCaptureTask: Task<Void, Never>? = nil
        
        for i in 0..<totalPhotos {
            // 1. Wait for previous capture to finish (if any)
            // We do this BEFORE the countdown to ensure that once the countdown starts,
            // nothing stops us from triggering at 0.
            if let task = previousCaptureTask {
                _ = await task.result
            }
            
            // 2. Countdown
            var countTime: Int
            
            if i == 0 {
                // First photo: Show guidance first (if enabled), then countdown
                if config.showGuidanceText {
                    self.showGuidance = true
                    // Wait 3 seconds for guidance
                    for _ in 0..<3 {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                    self.showGuidance = false
                    
                    // Calculate remaining countdown
                    // Reduce initial countdown by 3s, but ensure minimum of 3s
                    countTime = max(3, config.initialCountdownSec - 3)
                } else {
                    // Guidance disabled, use full initial countdown
                    countTime = config.initialCountdownSec
                }
            } else {
                countTime = config.interShotCountdownSec
            }
            
            // Run countdown
            for t in (1...countTime).reversed() {
                self.countdown = t
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            self.countdown = 0
            

            
            // 3. Trigger & Flash
            // Start flash immediately (no fade in)
            withAnimation(.linear(duration: 0)) { self.isFlashing = true }
            
            // Schedule flash to end
            Task {
                // Hold white for 0.5s
                try? await Task.sleep(nanoseconds: 500_000_000)
                
                await MainActor.run {
                    // Fade out over 0.5s
                    withAnimation(.easeIn(duration: 0.5)) { self.isFlashing = false }
                }
            }
            
            // 4. Start Capture in Background
            // We start this task and move immediately to the next loop iteration (next countdown)
            // The next iteration will await this task before triggering *its* capture.
            previousCaptureTask = Task {
                do {
                    print("Triggering capture at \(Date())")
                    let urls = try await cameraService.takePicture()
                    print("Capture returned at \(Date())")
                    
                    await MainActor.run {
                        if let first = urls.first {
                            self.capturedImages.append(first)
                        }
                    }
                    
                    self.saveToPhotoLibrary(urls: urls)
                } catch {
                    print("Capture failed: \(error)")
                }
            }
            
            // Wait for flash to finish fading before starting next countdown visual
            // The flash takes 1.0s total (0.5 hold + 0.5 fade).
            // We want the next countdown to start *after* the fade is done.
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        
        // Wait for the final capture to finish
        if let task = previousCaptureTask {
            _ = await task.result
        }
        
        transition(to: .review(images: capturedImages, index: 0))
    }
    
    private func saveToPhotoLibrary(urls: [String]) {
        guard config.saveToPhotos else { return }
        let service = self.cameraService
        
        Task.detached(priority: .background) {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else { return }
            
            for urlString in urls {
                // guard let url = URL(string: urlString) else { continue } // Not needed if we pass string to fetchImage
                
                do {
                    // Use the camera service to fetch the image data
                    // This handles both local files (LocalCameraClient) and remote URLs (SonyCameraClient)
                    // correctly using the appropriate session/permissions.
                    let data = try await service.fetchImage(url: urlString)
                    
                    try await PHPhotoLibrary.shared().performChanges {
                        let creationRequest = PHAssetCreationRequest.forAsset()
                        creationRequest.addResource(with: .photo, data: data, options: nil)
                    }
                } catch {
                    print("Failed to save photo: \(error)")
                }
            }
        }
    }
    
    private func startReviewSequence() async {
        guard case .review(let images, _) = state else { return }
        
        for i in 0..<images.count {
            self.state = .review(images: images, index: i)
            try? await Task.sleep(nanoseconds: UInt64(config.previewDurationSec) * 1_000_000_000)
        }
        
        transition(to: .idle)
    }
    
    func retryConnection() {
        transition(to: .initialization)
    }
    
    // MARK: - Heartbeat
    
    private func setupHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if case .error = self.state { return }
                if case .initialization = self.state { return }
                
                // Check connection status
                let isConnected = await self.cameraService.checkConnection()
                
                if !isConnected {
                    print("Heartbeat: Connection lost!")
                    // If we lose connection, treat it as a Wi-Fi mismatch/disconnect
                    // This will prompt the user to reconnect
                    if !self.config.useLocalCamera {
                        self.transition(to: .wifiMismatch(targetSSID: self.config.cameraSSID))
                    } else {
                        // For local camera, this shouldn't happen, but good to handle
                        self.transition(to: .error(message: "Camera disconnected"))
                    }
                }
            }
        }
    }
}
