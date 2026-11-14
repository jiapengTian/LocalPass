import SwiftUI
import UIKit

// MARK: - 锁屏状态

@MainActor
final class LockScreenModel: ObservableObject {

    enum Mode: Equatable {
        case password
        case gesture
    }

    @Published var mode: Mode
    @Published var password = ""
    @Published var pattern: [Int] = []
    @Published var isAuthenticating = false
    @Published var errorText: String?
    @Published var lockoutRemaining = 0
    @Published var shakeTrigger = 0
    @Published var showPassword = false

    private var failedAttempts = 0
    private var lockoutUntil: Date?
    private var didAutoPrompt = false

    private let session: VaultSession

    init(session: VaultSession) {
        self.session = session
        mode = session.header?.hasGesture == true ? .gesture : .password
    }

    var isLockedOut: Bool { lockoutRemaining > 0 }
    var canRetry: Bool { !isAuthenticating && !isLockedOut }
    var hasGesture: Bool { session.header?.hasGesture == true }
    var hint: String { (session.header?.hint ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }

    var biometricLabel: String {
        session.biometricStatus.canUse ? session.biometricKindName : "系统验证"
    }

    func autoPromptIfNeeded() async {
        guard !didAutoPrompt else { return }
        didAutoPrompt = true
        guard !isLockedOut, session.canOfferBiometric, session.shouldAutoPromptBiometric() else { return }
        await authenticateWithBiometrics()
    }

    func submitPassword() async {
        guard canRetry else { return }
        let candidate = password
        guard !candidate.isEmpty else {
            errorText = "请输入主密码"
            return
        }
        isAuthenticating = true
        errorText = nil
        let success = await session.unlock(password: candidate)
        isAuthenticating = false
        if success {
            password = ""
            failedAttempts = 0
        } else {
            failedAttempts += 1
            errorText = "主密码不正确（已输入 \(candidate.count) 个字符）"
            shakeTrigger += 1
            applyLockoutIfNeeded()
        }
    }

    func submitPattern(_ candidate: [Int]) async {
        guard canRetry else { return }
        guard candidate.count >= 4 else { pattern = []; return }
        isAuthenticating = true
        errorText = nil
        let success = await session.unlock(gesturePattern: candidate)
        isAuthenticating = false
        pattern = []
        if success {
            failedAttempts = 0
        } else {
            failedAttempts += 1
            errorText = "手势不正确，请重试"
            shakeTrigger += 1
            applyLockoutIfNeeded()
        }
    }

    func authenticateWithBiometrics() async {
        guard canRetry else { return }
        isAuthenticating = true
        errorText = nil
        let success = await session.unlockWithBiometric()
        isAuthenticating = false
        if success {
            failedAttempts = 0
        } else if session.canOfferBiometric {
            errorText = nil
        }
    }

    func switchTo(_ newMode: Mode) {
        guard mode != newMode else { return }
        mode = newMode
        errorText = nil
        password = ""
        pattern = []
        showPassword = false
    }

    private func applyLockoutIfNeeded() {
        let seconds: Int?
        switch failedAttempts {
        case 5..<7: seconds = 30
        case 7..<10: seconds = 120
        case 10...: seconds = 300
        default: seconds = nil
        }
        guard let seconds else { return }
        lockoutUntil = Date().addingTimeInterval(TimeInterval(seconds))
        lockoutRemaining = seconds
        errorText = "尝试次数过多，请等待 \(seconds) 秒后再试"
        startCountdown()
    }

    private func startCountdown() {
        Task { [weak self] in
            while let self, self.lockoutRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let until = self.lockoutUntil else { return }
                let remaining = Int(until.timeIntervalSinceNow.rounded(.up))
                self.lockoutRemaining = max(0, remaining)
                if self.lockoutRemaining == 0 {
                    self.lockoutUntil = nil
                    self.failedAttempts = 0
                    self.errorText = nil
                }
            }
        }
    }
}

// MARK: - 锁屏

struct LockScreenView: View {
    @ObservedObject var session: VaultSession
    @StateObject private var model: LockScreenModel
    @State private var showIntro = true
    @State private var showForgot = false

    init(session: VaultSession) {
        self.session = session
        _model = StateObject(wrappedValue: LockScreenModel(session: session))
    }

    var body: some View {
        ZStack {
            Theme.aurora(UIScreen.main.bounds.size)

            ScrollView {
                VStack(spacing: 0) {
                    logo
                        .padding(.top, 46)

                    Text("私钥库")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Theme.titleGradient)
                        .padding(.top, 24)

                    Text(model.mode == .gesture ? "绘制手势解锁" : "输入主密码解锁")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.text2)
                        .padding(.top, 6)

                    if model.mode == .gesture {
                        gestureBox
                    } else {
                        passwordBox
                    }

                    footer
                        .padding(.top, 30)
                }
                .padding(.horizontal, 26)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)

            if showIntro {
                LaunchIntroView()
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .shake(trigger: $model.shakeTrigger)
        .sheet(isPresented: $showForgot) {
            ForgotPasswordView(session: session, onRestored: {
                showForgot = false
                session.showToast("密码库已重建，请用新密码解锁", symbol: "checkmark.shield")
            })
        }
        .task {
            await model.autoPromptIfNeeded()
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(.easeOut(duration: 0.28)) { showIntro = false }
        }
    }

    // MARK: 部件

    private var logo: some View {
        ZStack {
            Circle()
                .fill(Theme.violet.opacity(0.45))
                .frame(width: 150, height: 150)
                .blur(radius: 40)

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Theme.brandGradient)
                .frame(width: 108, height: 108)
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Theme.violet.opacity(0.7), radius: 30, x: 0, y: 16)

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var passwordBox: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "key.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))

                Group {
                    if model.showPassword {
                        TextField("主密码", text: $model.password)
                    } else {
                        SecureField("主密码", text: $model.password)
                    }
                }
                .font(.system(size: 16.5))
                .foregroundStyle(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .textContentType(.password)
                .submitLabel(.go)
                .onSubmit { Task { await model.submitPassword() } }

                Button {
                    model.showPassword.toggle()
                } label: {
                    Image(systemName: model.showPassword ? "eye.slash" : "eye")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(model.showPassword ? 0.95 : 0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            )

            if !model.hint.isEmpty {
                Text("密码提示：\(model.hint)")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity)
            }

            Button {
                Task { await model.submitPassword() }
            } label: {
                if model.isAuthenticating {
                    ProgressView().tint(Color(hex: "#3D2FB8")!)
                } else {
                    Text(model.isLockedOut ? "请等待 \(model.lockoutRemaining) 秒" : "解锁")
                }
            }
            .buttonStyle(SolidWhiteButtonStyle(enabled: model.canRetry))
            .disabled(!model.canRetry)
            .padding(.top, 2)

            if session.canOfferBiometric {
                Button {
                    Task { await model.authenticateWithBiometrics() }
                } label: {
                    Label("使用 \(model.biometricLabel) 解锁", systemImage: "faceid")
                }
                .buttonStyle(GlassButtonStyle())
                .disabled(!model.canRetry)
            }

            if model.hasGesture {
                Button("使用手势解锁") {
                    model.switchTo(.gesture)
                }
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(Theme.text2)
                .padding(.top, 2)
            }

            if let error = model.errorText {
                Text(error)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "#FF9AA5")!)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }

            Button("忘记主密码？") {
                showForgot = true
            }
            .font(.system(size: 12.5))
            .foregroundStyle(.white.opacity(0.5))
            .padding(.top, 4)
        }
        .padding(.top, 26)
    }

    private var gestureBox: some View {
        VStack(spacing: 12) {
            PatternLockView(
                pattern: $model.pattern,
                isDisabled: !model.canRetry,
                onCompleted: { candidate in
                    Task { await model.submitPattern(candidate) }
                }
            )
            .frame(maxWidth: 300)
            .frame(height: 300)
            .padding(.top, 12)
            .overlay {
                if model.isAuthenticating {
                    ProgressView()
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }

            if let error = model.errorText {
                Text(error)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "#FF9AA5")!)
            }

            Button("改用主密码") {
                model.switchTo(.password)
            }
            .font(.system(size: 13.5, weight: .medium))
            .foregroundStyle(Theme.text2)
        }
        .padding(.top, 8)
    }

    private var footer: some View {
        VStack(spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 11))
                Text("数据只保存在这台设备上")
                    .font(.system(size: 12))
            }
            .foregroundStyle(Theme.text3)

            Text("忘记主密码将无法找回")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.text3.opacity(0.8))
        }
        .padding(.bottom, 26)
    }
}

// MARK: - 抖动

struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = 12 * sin(animatableData * .pi * 3)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

struct ShakeOnChange: ViewModifier {
    @Binding var trigger: Int
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .modifier(ShakeEffect(animatableData: phase))
            .onChange(of: trigger) { _ in
                withAnimation(.linear(duration: 0.32)) { phase += 1 }
            }
    }
}

extension View {
    func shake(trigger: Binding<Int>) -> some View {
        modifier(ShakeOnChange(trigger: trigger))
    }
}
