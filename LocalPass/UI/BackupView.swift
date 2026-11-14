import SwiftUI
import UniformTypeIdentifiers

// MARK: - 加密备份

struct BackupView: View {
    @ObservedObject var session: VaultSession
    @Environment(\.dismiss) private var dismiss

    @State private var exportPassword = ""
    @State private var exportConfirm = ""
    @State private var exporting = false
    @State private var exportedURL: URL?
    @State private var showImporter = false
    @State private var pendingImport: Data?
    @State private var showImportPrompt = false
    @State private var importPassword = ""
    @State private var importing = false
    @State private var errorText: String?

    private var canExport: Bool {
        exportPassword.count >= VaultPolicy.minimumPasswordLength
            && exportPassword == exportConfirm
            && !exporting
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        section("导出备份")
                        GlassCard(cornerRadius: 16) {
                            VStack(alignment: .leading, spacing: 10) {
                                SecureField("备份密码", text: $exportPassword)
                                    .modifier(DarkFieldStyle())
                                SecureField("再次输入", text: $exportConfirm)
                                    .modifier(DarkFieldStyle())
                                if !exportPassword.isEmpty {
                                    StrengthBar(password: exportPassword)
                                }

                                Button {
                                    Task { await runExport() }
                                } label: {
                                    if exporting {
                                        ProgressView().tint(.white)
                                    } else {
                                        Label("生成加密备份", systemImage: "square.and.arrow.up")
                                    }
                                }
                                .buttonStyle(PrimaryButtonStyle(enabled: canExport))
                                .disabled(!canExport)
                                .padding(.top, 4)

                                if let exportedURL {
                                    ShareLink(item: exportedURL) {
                                        Label("分享备份文件", systemImage: "paperplane")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Theme.violet2)
                                    }
                                }
                            }
                        }

                        Text("备份文件里是完整的加密数据，可以拷到电脑或另一台 iPhone。备份密码与主密码相互独立，请单独记住。")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.text3)
                            .padding(.top, 8)

                        section("从备份恢复")
                        GlassCard(cornerRadius: 16, padding: 0) {
                            Button {
                                showImporter = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "arrow.down.doc")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 34, height: 34)
                                        .background(
                                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                                .fill(Theme.violet.opacity(0.85))
                                        )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("选择备份文件并恢复")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Theme.text)
                                        Text("会覆盖当前库内容")
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
                            .disabled(importing)
                        }

                        if let errorText {
                            Text(errorText)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Color(hex: "#FF9AA5")!)
                                .padding(.top, 12)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("加密备份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(Theme.violet2)
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json, .data],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .alert("输入备份密码", isPresented: $showImportPrompt) {
                SecureField("备份密码", text: $importPassword)
                Button("恢复") { Task { await runImport() } }
                Button("取消", role: .cancel) {
                    pendingImport = nil
                    importPassword = ""
                }
            } message: {
                Text("请输入创建这份备份时设置的密码。")
            }
        }
    }

    private func section(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.1)
            .foregroundStyle(Theme.text3)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .padding(.leading, 4)
    }

    private func runExport() async {
        errorText = nil
        guard canExport else { return }
        exporting = true
        let url = await session.exportBackup(password: exportPassword)
        exporting = false
        if let url {
            exportedURL = url
            exportPassword = ""
            exportConfirm = ""
        } else {
            errorText = "导出失败，请重试。"
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        errorText = nil
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                pendingImport = try Data(contentsOf: url)
                importPassword = ""
                showImportPrompt = true
            } catch {
                errorText = "无法读取这个文件。"
            }
        case .failure:
            errorText = "选择文件失败。"
        }
    }

    private func runImport() async {
        guard let data = pendingImport else { return }
        importing = true
        let ok = await session.importBackup(data: data, password: importPassword)
        importing = false
        pendingImport = nil
        importPassword = ""
        if ok { dismiss() }
    }
}
