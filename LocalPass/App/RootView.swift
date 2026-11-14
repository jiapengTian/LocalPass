import SwiftUI

// MARK: - 根视图

struct RootView: View {
    @ObservedObject var session: VaultSession
    let settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase

    @State private var backgroundedAt: Date?

    var body: some View {
        ZStack {
            content

            if let toast = session.toast {
                VStack {
                    Spacer()
                    ToastView(message: toast) {
                        session.dismissToast()
                    }
                    .padding(.bottom, 22)
                }
                .ignoresSafeArea(.keyboard)
                .animation(.spring(response: 0.32, dampingFraction: 0.85), value: toast.id)
                .zIndex(10)
            }

            PrivacyCoverView(isVisible: isPrivacyCovered)
                .zIndex(5)
        }
        .environmentObject(settings)
        .task {
            await session.bootstrap()
            autoLockTick()
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhase(newPhase)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch session.phase {
        case .loading:
            ZStack {
                AuroraBackground()
                ProgressView().tint(Theme.violet2)
            }
        case .needSetup:
            SetupWizardView(session: session)
                .id(session.setupToken)
        case .locked:
            LockScreenView(session: session)
        case .unlocked:
            HomeView(session: session)
        }
    }

    private var isPrivacyCovered: Bool {
        scenePhase == .background
    }

    private func handleScenePhase(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            backgroundedAt = Date()
        case .active:
            autoLockTick()
        default:
            break
        }
    }

    private func autoLockTick() {
        guard session.phase == .unlocked else {
            backgroundedAt = nil
            return
        }
        if let backgroundedAt,
           let delay = settings.lockAfterSeconds,
           Date().timeIntervalSince(backgroundedAt) >= Double(delay) {
            session.lock()
        }
        backgroundedAt = nil
    }
}

// MARK: - 防偷窥遮罩

struct PrivacyCoverView: View {
    var isVisible: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#12162B")!, Color(hex: "#080A14")!],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(spacing: 14) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                Text("私钥库")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                Text("内容已隐藏")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.text3)
            }
        }
        .ignoresSafeArea()
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .animation(.linear(duration: 0.12), value: isVisible)
    }
}
