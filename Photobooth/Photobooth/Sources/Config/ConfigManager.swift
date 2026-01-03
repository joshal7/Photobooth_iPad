import Foundation
import Combine

class ConfigManager: ObservableObject {
    static let shared = ConfigManager()
    
    @Published var initialCountdownSec: Int
    @Published var interShotCountdownSec: Int
    @Published var photoCount: Int
    @Published var previewDurationSec: Int
    @Published var cameraEndpoint: String
    @Published var cameraSSID: String
    @Published var cameraPassword: String
    @Published var useLocalCamera: Bool
    @Published var saveToPhotos: Bool
    @Published var showGuidanceText: Bool
    @Published var enableImageSharing: Bool
    @Published var enableGIFMode: Bool
    @Published var gifFrameCount: Int
    @Published var gifCaptureInterval: Double
    @Published var gifFrameDuration: Double
    @Published var gifPreviewDuration: Double
    @Published var gifResolution: Int // 0: 720p, 1: 480p

    private init() {
        // Load from UserDefaults or use defaults
        self.initialCountdownSec = UserDefaults.standard.object(forKey: "initialCountdownSec") as? Int ?? 5
        self.interShotCountdownSec = UserDefaults.standard.object(forKey: "interShotCountdownSec") as? Int ?? 3
        self.photoCount = UserDefaults.standard.object(forKey: "photoCount") as? Int ?? 3
        self.previewDurationSec = UserDefaults.standard.object(forKey: "previewDurationSec") as? Int ?? 4
        self.cameraEndpoint = UserDefaults.standard.string(forKey: "cameraEndpoint") ?? "http://192.168.122.1:8080/sony"
        self.cameraSSID = UserDefaults.standard.string(forKey: "cameraSSID") ?? "DIRECT-1EE0:Sony_a7rii"
        self.cameraPassword = UserDefaults.standard.string(forKey: "cameraPassword") ?? "KjTb5LPc"
        self.useLocalCamera = UserDefaults.standard.object(forKey: "useLocalCamera") as? Bool ?? false
        self.saveToPhotos = UserDefaults.standard.object(forKey: "saveToPhotos") as? Bool ?? true // Default to true
        self.showGuidanceText = UserDefaults.standard.object(forKey: "showGuidanceText") as? Bool ?? true // Default to true
        self.enableImageSharing = UserDefaults.standard.object(forKey: "enableImageSharing") as? Bool ?? true // Default to true

        // Animated GIF Defaults
        self.enableGIFMode = UserDefaults.standard.object(forKey: "enableGIFMode") as? Bool ?? false
        self.gifFrameCount = UserDefaults.standard.object(forKey: "gifFrameCount") as? Int ?? 4
        self.gifCaptureInterval = UserDefaults.standard.object(forKey: "gifCaptureInterval") as? Double ?? 0.25
        self.gifFrameDuration = UserDefaults.standard.object(forKey: "gifFrameDuration") as? Double ?? 0.25
        self.gifPreviewDuration = UserDefaults.standard.object(forKey: "gifPreviewDuration") as? Double ?? 8.0
        self.gifResolution = UserDefaults.standard.object(forKey: "gifResolution") as? Int ?? 0 // Default 720p
        
        // Migration: Fix old default SSID if present
        if self.cameraSSID == "DIRECT-xxxx:Sony" {
            self.cameraSSID = "DIRECT-1EE0:Sony_a7rii"
            // Also ensure password is correct if it was empty/default
            if self.cameraPassword.isEmpty {
                self.cameraPassword = "KjTb5LPc"
            }
            save()
        }
    }
    
    func save() {
        UserDefaults.standard.set(initialCountdownSec, forKey: "initialCountdownSec")
        UserDefaults.standard.set(interShotCountdownSec, forKey: "interShotCountdownSec")
        UserDefaults.standard.set(photoCount, forKey: "photoCount")
        UserDefaults.standard.set(previewDurationSec, forKey: "previewDurationSec")
        UserDefaults.standard.set(cameraEndpoint, forKey: "cameraEndpoint")
        UserDefaults.standard.set(cameraSSID, forKey: "cameraSSID")
        UserDefaults.standard.set(cameraPassword, forKey: "cameraPassword")
        UserDefaults.standard.set(useLocalCamera, forKey: "useLocalCamera")
        UserDefaults.standard.set(saveToPhotos, forKey: "saveToPhotos")
        UserDefaults.standard.set(showGuidanceText, forKey: "showGuidanceText")
        UserDefaults.standard.set(enableImageSharing, forKey: "enableImageSharing")

        UserDefaults.standard.set(enableGIFMode, forKey: "enableGIFMode")
        UserDefaults.standard.set(gifFrameCount, forKey: "gifFrameCount")
        UserDefaults.standard.set(gifCaptureInterval, forKey: "gifCaptureInterval")
        UserDefaults.standard.set(gifFrameDuration, forKey: "gifFrameDuration")
        UserDefaults.standard.set(gifPreviewDuration, forKey: "gifPreviewDuration")
        UserDefaults.standard.set(gifResolution, forKey: "gifResolution")
    }
    
    func resetToDefaults() {
        self.initialCountdownSec = 5
        self.interShotCountdownSec = 3
        self.photoCount = 3
        self.previewDurationSec = 4
        self.cameraEndpoint = "http://192.168.122.1:8080/sony"
        self.cameraSSID = "DIRECT-1EE0:Sony_a7rii"
        self.cameraPassword = "KjTb5LPc"
        self.useLocalCamera = false
        self.saveToPhotos = true
        self.showGuidanceText = true
        self.enableImageSharing = true

        self.enableGIFMode = false
        self.gifFrameCount = 4
        self.gifCaptureInterval = 0.25
        self.gifFrameDuration = 0.25
        self.gifPreviewDuration = 8.0
        self.gifResolution = 0 // 720p
        save()
    }
}
