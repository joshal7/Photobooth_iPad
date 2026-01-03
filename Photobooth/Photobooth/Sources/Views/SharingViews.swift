import SwiftUI

struct SharingOverlayView: View {
    @EnvironmentObject var stateMachine: StateMachine
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                Text("Would you like your photos?")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                
                HStack(spacing: 40) {
                    // AirDrop Button
                    Button(action: {
                        stateMachine.selectAirDrop()
                    }) {
                        VStack {
                            Image(systemName: "airplayaudio") // Closest to AirDrop
                                .font(.system(size: 50))
                            Text("AirDrop")
                                .font(.headline)
                            Text("(iPhone Only)")
                                .font(.caption)
                        }
                        .frame(width: 200, height: 200)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }
                    
                    // No Thanks Button
                    Button(action: {
                        stateMachine.skipSharing()
                    }) {
                        VStack {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 50))
                            Text("No Thanks")
                                .font(.headline)
                        }
                        .frame(width: 200, height: 200)
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }
                }
            }
        }
    }
}



struct AirDropInstructionsView: View {
    @EnvironmentObject var stateMachine: StateMachine
    let images: [String]
    
    @State private var showSuccessMessage = false
    @State private var showFailureOptions = false
    @State private var isPreparing = false
    @State private var isSheetPresented = false
    
    @State private var resetWorkItem: DispatchWorkItem?
    @State private var pollTimer: Timer?
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if showSuccessMessage {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    Text("Transfer Successful!")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                }
                .transition(.scale)
            } else if showFailureOptions {
                // Completion Options
                VStack(spacing: 30) {
                    Text("Transfer Finished?")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)
                    
                    Button("Done") {
                        stateMachine.skipSharing()
                    }
                    .buttonStyle(ActionButtonStyle(color: .green))
                    .frame(width: 200) // Make Done button prominent
                    
                    Text("Or try another way:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.top, 10)
                    
                    HStack(spacing: 20) {
                        Button("Try Again") {
                            showFailureOptions = false
                            startAirDropProcess()
                        }
                        .buttonStyle(ActionButtonStyle(color: .blue))
                    }
                }
            } else {
                // Active Sharing State (Preparing or Sheet Presented)
                // We combine these to show instructions while the sheet is up
                ZStack {
                    VStack(spacing: 20) {
                        // Instructions at the top
                        VStack(alignment: .leading, spacing: 20) {
                            Text("(1) Settings > General > Airdrop > Everyone for 10 minutes")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.white)
                            
                            Text("(2) Click the Airdrop button below")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.white)
                        }
                        .fixedSize() // Ensure container hugs text so it centers properly as a block
                        .frame(maxWidth: .infinity) // Center the block horizontally
                        .padding(.top, 10) // Moved up further (was 40) to increase space from sheet
                        
                        Spacer()
                        
                        if isPreparing {
                            VStack(spacing: 20) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .colorScheme(.dark)
                                Text("Preparing images...")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        } else {
                            Text("Sharing...")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                    }
                    
                    // Overlay "Done" button
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                closeShareSheet()
                            }) {
                                Text("Done")
                                    .font(.headline)
                                    .bold()
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 30)
                                    .padding(.vertical, 15)
                                    .background(Color.blue)
                                    .cornerRadius(30)
                            }
                            .padding(40)
                        }
                        Spacer()
                    }
                }
            }
        }
        .onAppear {
            // Auto-start when view appears
            if !isSheetPresented && !showFailureOptions && !showSuccessMessage {
                startAirDropProcess()
            }
        }
        .onDisappear {
            cancelReset()
            pollTimer?.invalidate()
            pollTimer = nil
        }
    }
    
    private func closeShareSheet() {
        // Find the root VC and dismiss presented VC
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        
        rootVC.dismiss(animated: true)
    }
    
    private func startAirDropProcess() {
        isPreparing = true
        cancelReset() // Cancel any existing timers
        
        Task {
            var items: [Any] = []
            
            for path in images {
                if let url = URL(string: path) {
                    if url.isFileURL { // Covers file:// scheme
                         items.append(url)
                    } else {
                        // Remote URL: Download to temp
                        if let data = try? await URLSession.shared.data(from: url).0 {
                            let filename = url.lastPathComponent
                            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                            try? data.write(to: tempURL)
                            items.append(tempURL)
                        }
                    }
                }
            }
            
            await MainActor.run {
                isPreparing = false
                isSheetPresented = true
                presentShareSheet(items: items)
            }
        }
    }
    
    private func presentShareSheet(items: [Any]) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        // Exclude common non-AirDrop activities
        var excludedTypes: [UIActivity.ActivityType] = [
            .message,
            .mail,
            .print,
            .copyToPasteboard,
            .assignToContact,
            .saveToCameraRoll,
            .addToReadingList,
            .postToFlickr,
            .postToVimeo,
            .postToTencentWeibo,
            .postToTwitter,
            .postToFacebook,
            .openInIBooks,
            .markupAsPDF
        ]
        
        // Try to exclude "Save to Files" and others using raw strings
        excludedTypes.append(UIActivity.ActivityType(rawValue: "com.apple.CloudDocsUI.AddToiCloudDrive"))
        excludedTypes.append(UIActivity.ActivityType(rawValue: "com.apple.reminders.RemindersEditorExtension"))
        excludedTypes.append(UIActivity.ActivityType(rawValue: "com.apple.mobilenotes.SharingExtension"))
        
        activityVC.excludedActivityTypes = excludedTypes
        
        // iPad requires source view/rect for popover
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = rootVC.view
            popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        activityVC.completionWithItemsHandler = { _, completed, _, _ in
            print("ActivityVC Completion Handler Called. Completed: \(completed)")
            
            // Reset state
            isSheetPresented = false
            self.cancelReset() // Stop the 45s timer
            
            // Dismissal of the share sheet can sometimes conflict with state transitions if done too fast.
            // We wait a brief moment to ensure the sheet is fully dismissed before changing state.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("Executing skipSharing() from handler")
                stateMachine.skipSharing()
            }
        }
        
        rootVC.present(activityVC, animated: true)
        
        // Start 45s timer for the Share Sheet interaction
        scheduleReset(delay: 45.0)
        
        // SAFETY POLL: Check every 1s if the VC is still presented.
        // If the system dismisses it (e.g. after AirDrop) but fails to call the handler,
        // this will catch it and reset the app.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak rootVC] _ in
            Task { @MainActor [weak rootVC] in
                guard let rootVC = rootVC else {
                    pollTimer?.invalidate()
                    pollTimer = nil
                    return
                }
                
                // Stop polling if we are no longer in the sharing state
                if !isSheetPresented {
                    pollTimer?.invalidate()
                    pollTimer = nil
                    return
                }
                
                // Check if the rootVC is still presenting OUR activityVC
                // Note: We check if presentedViewController is nil, or if it's NOT the activityVC.
                // However, checking for nil is the safest "it's gone" check.
                if rootVC.presentedViewController == nil {
                    print("Safety Poll: Share Sheet is gone but handler didn't fire. Forcing reset.")
                    pollTimer?.invalidate()
                    pollTimer = nil
                    isSheetPresented = false
                    cancelReset()
                    stateMachine.skipSharing()
                }
            }
        }
    }
    
    private func scheduleReset(delay: TimeInterval) {
        cancelReset()
        let item = DispatchWorkItem {
            print("Inactivity timeout. Resetting.")
            closeShareSheet()
            stateMachine.skipSharing()
        }
        resetWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func cancelReset() {
        resetWorkItem?.cancel()
        resetWorkItem = nil
    }
}

struct ActionButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .frame(minWidth: 120)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
