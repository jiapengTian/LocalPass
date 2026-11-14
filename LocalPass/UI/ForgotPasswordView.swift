import SwiftUI
import UniformTypeIdentifiers

/// 忘记主密码：只能「用加密备份重建」或「清空重来」。
struct ForgotPasswordView: View {
    @ObservedObject var session: VaultSession
    var onRestored: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showImporter = false
    @State private var pendingRestore: Data?
    @State private var showBackupPrompt = false
    @State private var backupPassword = ""
    @State private var newPassword = ""
    @State private var newPassword2 = ""
    @State private var stage: Stage = .backupPassword
    @State private var showWipeConfirm = false
    @State private var wipeWord = ""
    @State private var showDiagnostics = false
    @State private var errorText: String?
    @State private var working = false

    private enum Stage {
        case backupPassword
        case newPassword
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()

                ScrollView {
                    VStack(spacing: 14) {
                        warningCard

                        cardButton(
                            symbol: "square.and.arrow.down",
                            title: "用加密备份重建",
                            subtitle: "有 .lpbk 备份和它的密码，就能设新主密码",
                            tint: Theme.mint
                        ) {
                            showImporter = true
                        }

                        cardButton(
                            symbol: "trash",
                            title: "清空并重新开始",
                            subtitle: "删除全部记录和图片视频，无法撤销",
                            tint: Theme.danger,
                            danger: true
                        ) {
                            wipeWord = ""
                            showWipeConfirm = true
                        }

                        cardButton(
                            symbol: "stethoscope",
                            title: "检查本机数据",
                            subtitle: "看看是密码记错，还是文件损坏",
                            tint: Theme.violet
                        ) {
                            showDiagnostics = true
                        }

                        Text("备份包含账号记录与缩略图；原始照片 / 视频不随备份导出。")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.text3)
                            .multilineTextAlignment(.center)
                            .padding(.top, 6)

                        if let errorText {
                            Text(errorText)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Color(hex: "#FF9AA5")!)
                                .multilineTextAlignment(.center)
                        }

                        Button("返回解锁") { dismiss() }
                            .buttonStyle(GlassButtonStyle())
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("忘记主密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json, .data],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .sheet(isPresented: $showBackupPrompt) {
                restoreSheet
            }
            .alert("确定清空所有数据？", isPresented: $showWipeConfirm) {
                TextField("输入 RESET 确认", text: $wipeWord)
                Button("清空并重建", role: .destructive) {
                    guard wipeWord.trimmingCharacters(in: .whitespaces).uppercased() == "RESET" else {
                        errorText = "未清空：需要输入 RESET"
                        return
                    }
                    Task {
                        working = true
                        await session.eraseEverything()
                        working = false
                        dismiss()
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("会删除密码库、媒体文件和全部设置，操作不可撤销。")
            }
            .sheet(isPresented: $showDiagnostics) {
                NavigationStack {
                    ZStack {
                        AuroraBackground()
                        ScrollView {
                            Text(session.diagnosticsText())
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Theme.text2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                        }
                    }
                    .navigationTitle("数据自检")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { showDiagnostics = false }
                        }
                    }
                }
            }
        }
    }

    // MARK: 部件

    private var warningCard: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Theme.amber)
            VStack(alignment: .leading, spacing: 4) {
                Text("没有找回通道")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.amberText)
                Text("主密码只在本机参与解密，服务器上没有任何数据，也没有客服能还原。下面只有这几条路。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.amber.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.amber.opacity(0.2), lineWidth: 1)
        )
    }

    private func cardButton(
        symbol: String,
        title: String,
        subtitle: String,
        tint: Color,
        danger: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(tint.opacity(0.85))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(danger ? Color(hex: "#FF9AA5")! : Theme.text)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.text3)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.text3)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.cardGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var restoreSheet: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if stage == .backupPassword {
                            Text("输入这份备份的备份密码")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.text)
                            SecureField("备份密码", text: $backupPassword)
                                .modifier(DarkFieldStyle())
                        } else {
                            Text("给重建后的库设置新主密码")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.text)
                            SecureField("新主密码（至少 8 位）", text: $newPassword)
                                .modifier(DarkFieldStyle())
                            SecureField("再输入一次", text: $newPassword2)
                                .modifier(DarkFieldStyle())
                        }

                        if let errorText {
                            Text(errorText)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Color(hex: "#FF9AA5")!)
                        }

                        Button {
                            advanceRestore()
                        } label: {
                            if working {
                                ProgressView().tint(.white)
                            } else {
                                Text(stage == .backupPassword ? "下一步" : "重建密码库")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(enabled: !working))
                        .disabled(working)
                        .padding(.top, 6)
                    }
                    .padding(18)
                }
            }
            .navigationTitle("从备份重建")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showBackupPrompt = false
                        pendingRestore = nil
                        backupPassword = ""
                        newPassword = ""
                        newPassword2 = ""
                        stage = .backupPassword
                        errorText = nil
                    }
                }
            }
        }
    }

    // MARK: 逻辑

    private func handleImport(_ result: Result<[URL], Error>) {
        errorText = nil
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                pendingRestore = try Data(contentsOf: url)
                backupPassword = ""
                newPassword = ""
                newPassword2 = ""
                stage = .backupPassword
                showBackupPrompt = true
            } catch {
                errorText = "无法读取这个文件。"
            }
        case .failure:
            errorText = "选择文件失败。"
        }
    }

    private func advanceRestore() {
        errorText = nil
        guard let data = pendingRestore else { return }

        if stage == .backupPassword {
            guard !backupPassword.isEmpty else {
                errorText = "请输入备份密码"
                return
            }
            // 先验证备份密码能否解开
            do {
                _ = try BackupService.restore(data: data, password: backupPassword)
                stage = .newPassword
            } catch {
                errorText = BackupError.describe(error)
            }
            return
        }

        guard newPassword.count >= VaultPolicy.minimumPasswordLength else {
            errorText = "新主密码至少 \(VaultPolicy.minimumPasswordLength) 位"
            return
        }
        guard newPassword == newPassword2 else {
            errorText = "两次输入不一致"
            return
        }

        working = true
        Task {
            let ok = await session.restoreFromBackup(
                data: data,
                backupPassword: backupPassword,
                newPassword: newPassword
            )
            working = false
            if ok {
                showBackupPrompt = false
                onRestored()
                dismiss()
            } else {
                errorText = "重建失败，请检查备份文件。"
            }
        }
    }
}

// MARK: - 深色输入框

struct DarkFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15))
            .foregroundStyle(Theme.text)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
    }
}
