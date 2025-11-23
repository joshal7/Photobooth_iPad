import SwiftUI

struct ReviewView: View {
    let images: [String]
    let currentIndex: Int
    @EnvironmentObject var stateMachine: StateMachine
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if currentIndex < images.count {
                AsyncImage(url: URL(string: images[currentIndex])) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .scaleEffect(2.0)
                            .colorScheme(.dark)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
                .transition(.opacity)
                .id(currentIndex)
            }
            
            // Optional: Overlay showing "Reviewing X of N"
            VStack {
                Spacer()
                Text("Reviewing \(currentIndex + 1) of \(images.count)")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 20)
            }
        }
    }
}
