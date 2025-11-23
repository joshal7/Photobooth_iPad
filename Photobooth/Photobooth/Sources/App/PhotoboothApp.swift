import SwiftUI

@main
struct PhotoboothApp: App {
    @StateObject private var stateMachine = StateMachine()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(stateMachine)
                .onAppear {
                    stateMachine.start()
                }
        }
    }
}
