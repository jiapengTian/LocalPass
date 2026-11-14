import SwiftUI

// MARK: - 设置

struct SettingsView: View {
    @ObservedObject var session: VaultSession
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var sheet: Sheet?
    @State private var showEraseConfirm = false
    @State private var working = false

    enum Sheet: String, Identifiable {
        case changePassword
        case gesture
        case backup
        case categories
        case info
        case health

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        section("解锁方式")
                        GlassCard(cornerRadius: 16, padding: 0) {
                            VStack(spacing: 0) {
                                row(
                                    symbol: "faceid",
                                    tint: Theme.cyan,
                                    title: "系统验证解锁",
                                    subtitle: session.header?.biometric == true ? "已开启" : "未开启"
                                ) {
                                    Task {
                                        working = true
                                        _ = await session.setBiometrics(session.header?.biometric != true)
                                        working = false
                                    }
                                }
                                Divider().overlay(Theme.stroke).padding(.leading, 50)
                                row(
                                    symbol: "hand.draw.fill",
                                    tint: Theme.violet,
                                    title: "手势解锁",
                                    subtitle: session.header?.hasGesture == true ? "已设置" : "未设置"
                                ) {
                                    sheet = .gesture
                                }
                                Divider().overlay(Theme.stroke).padding(.leading, 50)
                                row(
                                    symbol: "key.fill",
                                    tint: Theme.violet2,
                                    title: "修改主密码",
                                    subtitle: "主密码始终有效"
                                ) {
                                    sheet = .changePassword
                                }
                            }
                        }

                        section("安全")
                        GlassCard(cornerRadius: 16, padding: 0) {
                            VStack(spacing: 0) {
                                HStack(spacing: 12) {
                                    iconTile("clock", tint: Theme.amber)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("自动锁定")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Theme.text)
                                        Text("无操作后重新上锁")
                                            .font(.system(size: 11.5))
                                            .foregroundStyle(Theme.text3)
                                    }
                                    Spacer(minLength: 0)
                                    Picker("", selection: Binding(
                                        get: { settings.autoLockDelay },
                                        set: { settings.autoLockDelay = $0 }
                                    )) {
                                        ForEach(AppSettings.AutoLockDelay.allCases) { delay in
                                            Text(delay.title).tag(delay.rawValue)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(Theme.violet2)
                                }
                                .padding(14)

                                Divider().overlay(Theme.stroke).padding(.leading, 50)

                                HStack(spacing: 12) {
                                    iconTile("doc.on.clipboard", tint: Theme.cyan)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("复制后自动清空剪贴板")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Theme.text)
                                        Text("\(settings.clipboardClearSeconds) 秒后")
                                            .font(.system(size: 11.5))
                                            .foregroundStyle(Theme.text3)
                                    }
                                    Spacer(minLength: 0)
                                    Toggle("", isOn: $settings.clearClipboardEnabled)
                                        .labelsHidden()
                                        .tint(Theme.mint)
                                }
                                .padding(14)
                            }
                        }

                        section("数据")
                        GlassCard(cornerRadius: 16, padding: 0) {
                            VStack(spacing: 0) {
                                row(
                                    symbol: "square.grid.2x2",
                                    tint: Theme.amber,
                                    title: "分类管理",
                                    subtitle: "改名 / 换图标 / 删除"
                                ) {
                                    sheet = .categories
                                }
                                Divider().overlay(Theme.stroke).padding(.leading, 50)
                                row(
                                    symbol: "arrow.up.doc",
                                    tint: Theme.mint,
                                    title: "导出加密备份",
                                    subtitle: "用独立密码加密的 .lpbk 文件"
                                ) {
                                    sheet = .backup
                                }
                                Divider().overlay(Theme.stroke).padding(.leading, 50)
                                row(
                                    symbol: "stethoscope",
                                    tint: Theme.violet,
                                    title: "数据自检",
                                    subtitle: "查看库文件结构是否完好"
                                ) {
                                    sheet = .health
                                }
                            }
                        }

                        section("关于")
                        GlassCard(cornerRadius: 16, padding: 0) {
                            VStack(spacing: 0) {
                                infoRow("账号记录", "\(session.itemCount) 条")
                                Divider().overlay(Theme.stroke)
                                infoRow("媒体文件", "\(session.mediaCount) 个")
                                Divider().overlay(Theme.stroke)
                                infoRow("加密方式", "AES-256-GCM")
                                Divider().overlay(Theme.stroke)
                                infoRow("版本", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            }
                        }

                        GlassCard(cornerRadius: 16, padding: 0) {
                            Button(role: .destructive) {
                                showEraseConfirm = true
                            } label: {
                                HStack(spacing: 12) {
                                    iconTile("trash", tint: Theme.danger)
                                    Text("清空所有数据并重置")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color(hex: "#FF9AA5")!)
                                    Spacer(minLength: 0)
                                }
                                .padding(14)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 20)

                        Text("数据只保存在本机，没有云端同步，也不会上传到任何服务器。")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.text3)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 16)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }

                if working {
                    ProgressView()
                        .padding(18)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(Theme.violet2)
                }
            }
            .sheet(item: $sheet) { item in
                switch item {
                case .changePassword:
                    ChangePasswordView(session: session)
                case .gesture:
                    GestureSetupView(session: session)
                case .backup:
                    BackupView(session: session)
                case .categories:
                    CategoryListView(session: session)
                case .info:
                    SecurityInfoView()
                case .health:
                    HealthView(text: session.diagnosticsText())
                }
            }
            .confirmationDialog("确定清空所有数据？", isPresented: $showEraseConfirm, titleVisibility: .visible) {
                Button("清空并重置", role: .destructive) {
                    Task {
                        await session.eraseEverything()
                        dismiss()
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("所有账号、照片、视频和设置会被永久删除，无法恢复。")
            }
        }
    }

    // MARK: 部件

    private func section(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.1)
            .foregroundStyle(Theme.text3)
            .padding(.top, 20)
            .padding(.bottom, 8)
            .padding(.leading, 4)
    }

    private func iconTile(_ symbol: String, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(tint.opacity(0.85))
            )
    }

    private func row(
        symbol: String,
        tint: Color,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                iconTile(symbol, tint: tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.text)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.text3)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.text3)
            }
            .padding(14)
        }
        .buttonStyle(.plain)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(Theme.text)
            Spacer()
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(Theme.text3)
        }
        .padding(14)
    }
}

// MARK: - 修改主密码

struct ChangePasswordView: View {
    @ObservedObject var session: VaultSession
    @Environment(\.dismiss) private var dismiss

    @State private var current = ""
    @State private var next = ""
    @State private var confirm = ""
    @State private var reveal = false
    @State private var saving = false
    @State private var errorText: String?

    private var canSubmit: Bool {
        !current.isEmpty
            && next.count >= VaultPolicy.minimumPasswordLength
            && next == confirm
            && !saving
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("当前主密码")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.text3)
                        SecureField("当前主密码", text: $current)
                            .modifier(DarkFieldStyle())

                        Text("新主密码")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.text3)
                            .padding(.top, 6)
                        Group {
                            if reveal {
                                TextField("新主密码", text: $next)
                            } else {
                                SecureField("新主密码", text: $next)
                            }
                        }
                        .modifier(DarkFieldStyle())

                        if !next.isEmpty { StrengthBar(password: next) }

                        SecureField("再次输入新主密码", text: $confirm)
                            .modifier(DarkFieldStyle())

                        Button {
                            reveal.toggle()
                        } label: {
                            Text(reveal ? "隐藏密码" : "显示新密码，检查一下")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.violet2)
                        }
                        .buttonStyle(.plain)

                        if let errorText {
                            Text(errorText)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Color(hex: "#FF9AA5")!)
                        }

                        Button {
                            submit()
                        } label: {
                            if saving {
                                ProgressView().tint(.white)
                            } else {
                                Text("保存")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(enabled: canSubmit))
                        .disabled(!canSubmit)
                        .padding(.top, 6)

                        Text("至少 \(VaultPolicy.minimumPasswordLength) 位。修改后请务必记住，忘记将无法恢复数据。")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.text3)
                    }
                    .padding(18)
                }
            }
            .navigationTitle("修改主密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(Theme.text2)
                }
            }
        }
    }

    private func submit() {
        guard canSubmit else { return }
        saving = true
        errorText = nil
        Task {
            let ok = await session.changeMasterPassword(current: current, new: next)
            saving = false
            if ok {
                dismiss()
            } else {
                errorText = "当前密码不正确，或新密码不符合要求。"
            }
        }
    }
}

// MARK: - 手势设置

struct GestureSetupView: View {
    @ObservedObject var session: VaultSession
    @Environment(\.dismiss) private var dismiss

    @State private var stage: Stage = .draw
    @State private var first: [Int]?
    @State private var pattern: [Int] = []
    @State private var tip = "连接至少 4 个点"
    @State private var saving = false

    private enum Stage { case draw, confirm }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()

                VStack(spacing: 14) {
                    Text(stage == .draw ? "绘制新手势" : "再画一次确认")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Theme.titleGradient)
                        .padding(.top, 18)

                    Text(tip)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.text2)

                    PatternLockView(
                        pattern: $pattern,
                        isDisabled: saving,
                        onCompleted: { candidate in handle(candidate) }
                    )
                    .frame(maxWidth: 290)
                    .frame(height: 290)
                    .padding(.top, 6)

                    Spacer(minLength: 0)

                    if session.header?.hasGesture == true {
                        Button(role: .destructive) {
                            saving = true
                            Task {
                                _ = await session.disableGesture()
                                saving = false
                                dismiss()
                            }
                        } label: {
                            Text("关闭手势解锁")
                        }
                        .buttonStyle(GlassButtonStyle())
                        .foregroundStyle(Color(hex: "#FF9AA5")!)
                    }

                    Button("取消") { dismiss() }
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.text2)
                        .padding(.bottom, 12)
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("手势解锁")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(Theme.text2)
                }
            }
        }
    }

    private func handle(_ candidate: [Int]) {
        guard !saving else { return }
        guard candidate.count >= VaultPolicy.minimumPatternDots else {
            pattern = []
            tip = "至少要连接 \(VaultPolicy.minimumPatternDots) 个点"
            return
        }

        switch stage {
        case .draw:
            first = candidate
            pattern = []
            stage = .confirm
            tip = "再画一次确认"
        case .confirm:
            guard let firstPattern = first, firstPattern == candidate else {
                first = nil
                pattern = []
                stage = .draw
                tip = "两次手势不一致，请重新绘制"
                return
            }
            saving = true
            Task {
                let ok = await session.setGesture(candidate)
                saving = false
                if ok { dismiss() } else {
                    stage = .draw
                    first = nil
                    tip = "保存失败，请重试"
                }
            }
        }
    }
}

// MARK: - 安全说明 / 自检

struct SecurityInfoView: View {
    @Environment(\.dismiss) private var dismiss

    private let points: [(String, String, String)] = [
        ("lock.shield", "AES-256-GCM 全库加密", "账号、密码、备注序列化后整体加密，改一个字节就会校验失败。"),
        ("key", "PBKDF2 密钥派生", "主密码经 PBKDF2-HMAC-SHA256（12 万轮）派生，手势有独立盐值。"),
        ("iphone", "只在本机存储", "文件位于沙盒 Application Support，受 iOS 数据保护；不联网、不上传。"),
        ("faceid", "系统验证解锁", "库密钥存在本机钥匙串，读取时必须通过 Face ID / Touch ID / 设备密码。"),
        ("eye.slash", "防偷窥", "切后台时界面会被遮罩；密码默认圆点显示；剪贴板定时清空。"),
        ("trash.slash", "无法找回", "没有服务器、没有账号体系。忘记主密码只能清空或用加密备份重建。")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(points.indices, id: \.self) { index in
                            let point = points[index]
                            GlassCard(cornerRadius: 16) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 9) {
                                        Image(systemName: point.0)
                                            .foregroundStyle(Theme.violet2)
                                        Text(point.1)
                                            .font(.system(size: 13.5, weight: .semibold))
                                            .foregroundStyle(Theme.text)
                                    }
                                    Text(point.2)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.text2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("安全设计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(Theme.violet2)
                }
            }
        }
    }
}

struct HealthView: View {
    var text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                ScrollView {
                    GlassCard(cornerRadius: 16) {
                        Text(text)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Theme.text2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("数据自检")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(Theme.violet2)
                }
            }
        }
    }
}
