import SwiftUI

// MARK: - 首次初始化

struct SetupWizardView: View {
    @ObservedObject var session: VaultSession
    @StateObject private var model = SetupWizardModel()

    var body: some View {
        ZStack {
            AuroraBackground()

            ScrollView {
                VStack(spacing: 0) {
                    progress
                        .padding(.top, 18)

                    switch model.step {
                    case .password: passwordStep
                    case .biometrics: biometricStep
                    case .gesture: gestureStep
                    case .summary: summaryStep
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onChange(of: model.errorText) { value in
            if let value {
                session.showToast(value, symbol: "exclamationmark.triangle")
            }
        }
    }

    // MARK: 进度

    private var progress: some View {
        HStack(spacing: 7) {
            ForEach(SetupWizardModel.Step.allCases, id: \.self) { step in
                Capsule()
                    .fill(step.rawValue <= model.step.rawValue
                          ? AnyShapeStyle(Theme.brandGradient)
                          : AnyShapeStyle(Color.white.opacity(0.1)))
                    .frame(height: 4)
            }
        }
        .padding(.bottom, 26)
    }

    // MARK: 第 1 步

    private var passwordStep: some View {
        VStack(spacing: 14) {
            heroIcon("key.fill")
            Text("设置主密码")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.titleGradient)
            Text("这是打开私钥库的唯一钥匙。它只用于在本机加密数据，不会上传到任何服务器。")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.text2)
                .multilineTextAlignment(.center)
                .padding(.bottom, 6)

            GlassCard(cornerRadius: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    fieldLabel("主密码")
                    Group {
                        if model.reveal {
                            TextField("至少 \(VaultPolicy.minimumPasswordLength) 位", text: $model.password)
                        } else {
                            SecureField("至少 \(VaultPolicy.minimumPasswordLength) 位", text: $model.password)
                        }
                    }
                    .modifier(DarkFieldStyle())

                    if !model.password.isEmpty {
                        StrengthBar(password: model.password)
                    }

                    fieldLabel("再次输入")
                    Group {
                        if model.reveal {
                            TextField("确认主密码", text: $model.confirmPassword)
                        } else {
                            SecureField("确认主密码", text: $model.confirmPassword)
                        }
                    }
                    .modifier(DarkFieldStyle())

                    Button {
                        model.reveal.toggle()
                    } label: {
                        Text(model.reveal ? "隐藏密码" : "显示密码，检查一下")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.violet2)
                    }
                    .buttonStyle(.plain)

                    fieldLabel("密码提示（可选）")
                    TextField("例如：老地方的邮编", text: $model.hint)
                        .modifier(DarkFieldStyle())
                }
            }

            warning

            Button("下一步") { model.step = .biometrics }
                .buttonStyle(PrimaryButtonStyle(enabled: model.passwordIsValid))
                .disabled(!model.passwordIsValid)
                .padding(.top, 6)
        }
    }

    private var warning: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15))
                .foregroundStyle(Theme.amber)
            VStack(alignment: .leading, spacing: 3) {
                Text("请务必记住这个密码")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.amberText)
                Text("数据只在这台设备上，没有找回服务。忘记主密码就只能清空，或用加密备份重建。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Theme.amber.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Theme.amber.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: 第 2 步

    private var biometricStep: some View {
        VStack(spacing: 14) {
            heroIcon("faceid")
            Text("系统验证解锁")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.titleGradient)
            Text(session.biometricStatus.canUse
                 ? "可以用 \(session.biometricStatus.kind) 或设备密码快速解锁。"
                 : session.biometricStatus.unavailableMessage)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.text2)
                .multilineTextAlignment(.center)
                .padding(.bottom, 6)

            GlassCard(cornerRadius: 18, padding: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "faceid")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(Theme.cyan.opacity(0.85))
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.biometricStatus.canUse ? "用 \(session.biometricStatus.kind) 解锁" : "系统验证不可用")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.text)
                        Text("库密钥会存进只有本机可读的钥匙串")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.text3)
                    }
                    Spacer(minLength: 0)
                    Toggle("", isOn: $model.useBiometrics)
                        .labelsHidden()
                        .tint(Theme.mint)
                        .disabled(!session.biometricStatus.canUse)
                }
                .padding(14)
            }

            Button("下一步") { model.step = .gesture }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 6)

            Button("跳过这一步") {
                model.useBiometrics = false
                model.step = .gesture
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.text2)
        }
    }

    // MARK: 第 3 步

    private var gestureStep: some View {
        VStack(spacing: 12) {
            heroIcon("hand.draw.fill")
            Text("设置手势解锁")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.titleGradient)
            Text(model.gestureStage == .first ? "连接至少 4 个点，画出你的手势" : "再画一次，确认手势")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.text2)
                .padding(.bottom, 4)

            PatternLockView(pattern: $model.pattern, onCompleted: { candidate in
                model.handlePattern(candidate)
            })
            .frame(maxWidth: 290)
            .frame(height: 290)

            if model.gestureStage == .confirm {
                Button("重新绘制") { model.resetGesture() }
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text2)
            }

            Button("下一步") { model.step = .summary }
                .buttonStyle(PrimaryButtonStyle(enabled: model.confirmedPattern != nil))
                .disabled(model.confirmedPattern == nil)
                .padding(.top, 4)

            Button("不设置手势，只使用主密码") {
                model.skipGesture()
                model.step = .summary
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.text2)
        }
    }

    // MARK: 第 4 步

    private var summaryStep: some View {
        VStack(spacing: 14) {
            heroIcon("checkmark.shield.fill")
            Text("一切就绪")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.titleGradient)
            Text("确认一下解锁方式，然后创建密码库。")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.text2)

            GlassCard(cornerRadius: 18, padding: 0) {
                VStack(spacing: 0) {
                    summaryRow("key.fill", "主密码", "已设置", Theme.mint)
                    Divider().overlay(Theme.stroke).padding(.leading, 46)
                    summaryRow(
                        "faceid",
                        "系统验证",
                        model.useBiometrics && session.biometricStatus.canUse ? "已开启" : "未开启",
                        model.useBiometrics && session.biometricStatus.canUse ? Theme.mint : Theme.text3
                    )
                    Divider().overlay(Theme.stroke).padding(.leading, 46)
                    summaryRow(
                        "hand.draw.fill",
                        "手势解锁",
                        model.confirmedPattern != nil ? "已设置" : "未设置",
                        model.confirmedPattern != nil ? Theme.mint : Theme.text3
                    )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                securityLine("AES-256-GCM 加密整个密码库")
                securityLine("PBKDF2-HMAC-SHA256（12 万轮）派生密钥")
                securityLine("文件受 iOS 数据保护，仅本机可读")
                securityLine("不联网、不备份到 iCloud、不上传")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.cardGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )

            Button {
                Task {
                    await session.createVault(
                        password: model.password,
                        hint: model.hint.trimmingCharacters(in: .whitespacesAndNewlines),
                        gesturePattern: model.confirmedPattern,
                        enableBiometrics: model.useBiometrics
                    )
                }
            } label: {
                if session.busy {
                    ProgressView().tint(.white)
                } else {
                    Text("创建密码库")
                }
            }
            .buttonStyle(PrimaryButtonStyle(enabled: !session.busy))
            .disabled(session.busy)
            .padding(.top, 4)

            Button("返回上一步") { model.step = .gesture }
                .font(.system(size: 13))
                .foregroundStyle(Theme.text2)
        }
    }

    // MARK: 部件

    private func heroIcon(_ symbol: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.violet.opacity(0.28), Theme.violet.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: symbol)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Theme.violet2)
        }
        .frame(width: 78, height: 78)
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Theme.violet.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Theme.violet.opacity(0.45), radius: 22, x: 0, y: 12)
        .padding(.top, 6)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(Theme.text3)
    }

    private func summaryRow(_ symbol: String, _ title: String, _ value: String, _ tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(Theme.violet2)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.text)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
    }

    private func securityLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(Theme.mint)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - 向导状态

@MainActor
final class SetupWizardModel: ObservableObject {

    enum Step: Int, CaseIterable, Hashable {
        case password = 0
        case biometrics = 1
        case gesture = 2
        case summary = 3
    }

    enum GestureStage {
        case first
        case confirm
    }

    @Published var step: Step = .password
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var hint = ""
    @Published var useBiometrics = true
    @Published var reveal = false
    @Published var pattern: [Int] = []
    @Published var gestureStage: GestureStage = .first
    @Published var confirmedPattern: [Int]?
    @Published var errorText: String?

    var passwordIsValid: Bool {
        password.count >= VaultPolicy.minimumPasswordLength
            && password == confirmPassword
            && !password.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func handlePattern(_ candidate: [Int]) {
        switch gestureStage {
        case .first:
            guard candidate.count >= VaultPolicy.minimumPatternDots else {
                pattern = []
                return
            }
            confirmedPattern = candidate
            pattern = []
            gestureStage = .confirm
            errorText = nil
        case .confirm:
            if candidate == confirmedPattern {
                confirmedPattern = candidate
                errorText = nil
            } else {
                confirmedPattern = nil
                pattern = []
                gestureStage = .first
                errorText = "两次手势不一致，请重新绘制"
            }
        }
    }

    func resetGesture() {
        confirmedPattern = nil
        pattern = []
        gestureStage = .first
    }

    func skipGesture() {
        resetGesture()
    }
}
