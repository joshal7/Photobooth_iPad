import SwiftUI

struct ContentView: View {
    @EnvironmentObject var stateMachine: StateMachine

    @State private var showSettings = false
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Background Live View (Always visible in Idle/Capture)
            if case .idle = stateMachine.state {
                LiveView()
            } else if case .capture = stateMachine.state {
                LiveView()
            }
            
            // Overlays based on state
            switch stateMachine.state {
            case .initialization:
                ProgressView("Connecting to Camera...")
                    .foregroundColor(.white)
                    .scaleEffect(1.5)
                
            case .idle:
                ZStack {
                    VStack {
                        Spacer()
                        Text("TAP TO TAKE \(ConfigManager.shared.photoCount) PHOTO\(ConfigManager.shared.photoCount == 1 ? "" : "S")")
                            .font(.system(size: 60, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.bottom, 50)
                            .shadow(radius: 10)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        stateMachine.triggerCapture()
                    }
                    
                    
                }
                
            case .capture:
                ZStack {
                    if stateMachine.showGuidance {
                        LookAtCameraView(useLocalCamera: ConfigManager.shared.useLocalCamera)
                            .transition(.opacity)
                            .zIndex(1)
                    } else {
                        CountdownView()
                            .transition(.opacity)
                    }
                    
                    // Photo counter in upper right
                    if stateMachine.currentPhotoNumber > 0 {
                        VStack {
                            HStack {
                                Spacer()
                                Text("\(stateMachine.currentPhotoNumber) of \(ConfigManager.shared.photoCount)")
                                    .font(.system(size: 60, weight: .heavy))
                                    .foregroundColor(.white)
                                    .shadow(radius: 10)
                                    .padding(.top, 50)
                                    .padding(.trailing, 50)
                            }
                            Spacer()
                        }
                    }
                }
                
            case .review(let images, let index):
                ReviewView(images: images, currentIndex: index)
                
            case .error(let message):
                ErrorView(message: message)
                
            case .wifiMismatch(let targetSSID):
                VStack(spacing: 20) {
                    Text("Connect to the Camera's WiFi")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("\"\(targetSSID)\"")
                        .font(.system(size: 30, weight: .heavy, design: .monospaced))
                        .foregroundColor(.yellow)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                    
                    Button(action: {
                        UIPasteboard.general.string = ConfigManager.shared.cameraPassword
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Copy Password")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.5))
                        .cornerRadius(10)
                    }
                    .padding(.bottom, 10)
                    
                    Button(action: {
                        // Try multiple URL schemes to open Wi-Fi settings
                        let schemes = [
                            "App-Prefs:root=WIFI",
                            "App-Prefs:WIFI",
                            "prefs:root=WIFI"
                        ]
                        
                        func openScheme(index: Int) {
                            guard index < schemes.count else { return }
                            if let url = URL(string: schemes[index]) {
                                UIApplication.shared.open(url, options: [:]) { success in
                                    if !success {
                                        openScheme(index: index + 1)
                                    }
                                }
                            } else {
                                openScheme(index: index + 1)
                            }
                        }
                        
                        openScheme(index: 0)
                    }) {
                        Text("Open Wi-Fi Settings")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        stateMachine.forceConnection()
                    }) {
                        Text("I'm connected, try anyway")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top, 10)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.8))
                .cornerRadius(20)
                
            case .sharingPrompt:
                SharingOverlayView()
                
            case .airDrop(let images):
                AirDropInstructionsView(images: images)
            }
            
            // Global Settings Button Overlay
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 24, weight: .light))
                            .foregroundColor(.white.opacity(0.6))
                            .padding()
                    }
                }
                Spacer()
            }
            
            // Flash Overlay
            if stateMachine.isFlashing {
                Color.white
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                    .zIndex(2) // Ensure it's on top
            }
        }
        .statusBar(hidden: true)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}
