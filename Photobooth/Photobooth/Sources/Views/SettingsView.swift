import SwiftUI

struct SettingsView: View {
    @ObservedObject var config = ConfigManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Timers & Counts")) {
                    Stepper("Initial Countdown: \(config.initialCountdownSec)s", value: $config.initialCountdownSec, in: 1...10)
                    Stepper("Between Shots: \(config.interShotCountdownSec)s", value: $config.interShotCountdownSec, in: 1...10)
                    Stepper("Photo Count: \(config.photoCount)", value: $config.photoCount, in: 1...10)
                    Stepper("Preview Duration: \(config.previewDurationSec)s", value: $config.previewDurationSec, in: 1...10)
                }
                
                Section(header: Text("General")) {
                    Toggle("Save to Photos", isOn: $config.saveToPhotos)
                    Toggle("Show Guidance Text", isOn: $config.showGuidanceText)
                }
                
                Section(header: Text("Camera Configuration")) {
                    Picker("Camera Source", selection: Binding(
                        get: { config.useLocalCamera ? 0 : 1 },
                        set: { config.useLocalCamera = ($0 == 0) }
                    )) {
                        Text("iPad Camera").tag(0)
                        Text("External Camera").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if !config.useLocalCamera {
                        HStack {
                            Text("Endpoint")
                            Spacer()
                            TextField("http://...", text: $config.cameraEndpoint)
                                .multilineTextAlignment(.trailing)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .foregroundColor(.gray)
                        }
                        
                        HStack {
                            Text("Camera SSID")
                            Spacer()
                            TextField("DIRECT-xxxx:Sony", text: $config.cameraSSID)
                                .multilineTextAlignment(.trailing)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .foregroundColor(.gray)
                        }
                        
                        HStack {
                            Text("Password")
                            Spacer()
                            TextField("Password", text: $config.cameraPassword)
                                .multilineTextAlignment(.trailing)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            Button(action: {
                                UIPasteboard.general.string = config.cameraPassword
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.blue)
                            }
                        }
                        

                        
                    }

                    
                }
                
                if !config.useLocalCamera {
                    Section(header: Text("Connection Instructions")) {
                        VStack(alignment: .leading, spacing: 10) {
                            Group {
                                Text("Required:")
                                    .font(.subheadline)
                                    .bold()
                                Text("• Open 'Smart Remote Control' app on Camera.")
                                Text("• Keep Camera and iPad plugged into power.")
                            }
                            
                            Group {
                                Text("Recommended:")
                                    .font(.subheadline)
                                    .bold()
                                    .padding(.top, 5)
                                Text("• Disable 'Auto-Join' for other Wi-Fi networks in iPad Settings.")
                                Text("• This ensures the iPad automatically reconnects to the Camera if the connection drops.")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 5)
                    }
                }
                
                Section(header: Text("Actions")) {
                    Button("Reset to Defaults") {
                        config.resetToDefaults()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        config.save()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
