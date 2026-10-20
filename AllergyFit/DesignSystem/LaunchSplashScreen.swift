import SwiftUI

/// Branded launch / loading splash screen directly mirroring Screen 5.
/// Features a warm organic avocado-to-lime gradient mesh, elegant serif typography,
/// companion presence, and an animated ring loader.
struct LaunchSplashScreen: View {
    @State private var isSpinning: Bool = false
    @State private var pulseScale: CGFloat = 0.96

    var body: some View {
        ZStack {
            // Organic Warm Avocado-To-Lime Mesh Gradient
            LinearGradient(
                colors: [
                    Color(hex: 0x589139), // Rich vivid green
                    Color(hex: 0x76B843), // Avocado lime
                    Color(hex: 0xA7D149), // Sunlit chartreuse
                    Color(hex: 0xC6D953)  // Warm honey lime
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle ambient mesh overlay
            RadialGradient(
                colors: [
                    Color(hex: 0xD8E866).opacity(0.35),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 50,
                endRadius: 400
            )
            .ignoresSafeArea()

            VStack {
                Spacer()

                // Center Brand Identity
                VStack(spacing: 12) {
                    // Companion Pip Icon
                    Image("pip_happy")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .scaleEffect(pulseScale)
                        .shadow(color: Color.black.opacity(0.12), radius: 12, y: 6)

                    Text("AllergyFit")
                        .font(.system(size: 42, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .shadow(color: Color.black.opacity(0.12), radius: 6, y: 2)

                    Text("Nourish safely · Grow together")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.88))
                        .tracking(0.5)
                }

                Spacer()

                // Delicate Spinning Ring Loader (Screen 5 Bottom)
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 2.5)
                        .frame(width: 38, height: 38)

                    Circle()
                        .trim(from: 0.1, to: 0.75)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .frame(width: 38, height: 38)
                        .rotationEffect(.degrees(isSpinning ? 360 : 0))
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                isSpinning = true
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                pulseScale = 1.04
            }
        }
    }
}
