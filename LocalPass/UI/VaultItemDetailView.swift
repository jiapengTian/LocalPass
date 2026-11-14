import SwiftUI

// MARK: - 详情

struct VaultItemDetailView: View {
    @ObservedObject var session: VaultSession
    var itemID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var revealed = false
    @State private var showDeleteConfirm = false
    @State private var editing: VaultItem?

    private var item: VaultItem? { session.item(withID: itemID) }

    var body: some View {
        ZStack {
            AuroraBackground()

            if let item {
                content(item)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "trash")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(Theme.text3)
                    Text("这条记录已被删除")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.text2)
                }
                .onAppear { dismiss() }
            }
        }
        .navigationTitle(item?.title ?? "详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("编辑") {
                    if let item { editing = item }
                }
                .foregroundStyle(Theme.violet2)
            }
        }
        .sheet(item: $editing) { target in
            ItemEditorView(session: session, mode: .edit(target))
        }
        .confirmationDialog(
            "删除「\(item?.title ?? "")」？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let item {
                    Task {
                        await session.delete(item)
                        dismiss()
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后无法恢复，除非你有加密备份。")
        }
        .onReceive(NotificationCenter.default.publisher(for: VaultNotifications.didLock)) { _ in
            dismiss()
        }
    }

    private func content(_ item: VaultItem) -> some View {
        ZenScroll {
            VStack(spacing: 12) {
                hero(item)

                GlassCard(cornerRadius: 18, padding: 0) {
                    VStack(spacing: 0) {
                        row(
                            symbol: "person.fill",
                            label: "账号",
                            value: item.username.isEmpty ? "未填写" : item.username,
                            mono: false
                        ) {
                            Button {
                                session.copyUsername(of: item)
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.violet2)
                            .disabled(item.username.isEmpty)
                        }

                        Divider().overlay(Theme.stroke)

                        row(
                            symbol: "key.fill",
                            label: "密码",
                            value: revealed ? item.password : String(repeating: "•", count: max(8, item.password.count)),
                            mono: true
                        ) {
                            HStack(spacing: 16) {
                                Button {
                                    withAnimation(.easeOut(duration: 0.15)) { revealed.toggle() }
                                } label: {
                                    Image(systemName: revealed ? "eye.slash" : "eye")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Theme.violet2)

                                Button {
                                    session.copyPassword(of: item)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Theme.violet2)
                            }
                            .disabled(item.password.isEmpty)
                        }
                    }
                }

                if !item.url.isEmpty || !item.notes.isEmpty || !item.tags.isEmpty {
                    GlassCard(cornerRadius: 18) {
                        VStack(alignment: .leading, spacing: 14) {
                            if !item.url.isEmpty {
                                labeled("网址") {
                                    Text(item.url)
                                        .font(.system(size: 12.5))
                                        .foregroundStyle(Theme.violet2)
                                        .textSelection(.enabled)
                                        .lineLimit(2)
                                }
                            }
                            if !item.tags.isEmpty {
                                labeled("标签") {
                                    HStack(spacing: 6) {
                                        ForEach(item.tags, id: \.self) { tag in
                                            Text("#\(tag)")
                                                .font(.system(size: 11.5))
                                                .foregroundStyle(Theme.violet2)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 3)
                                                .background(
                                                    Capsule().fill(Theme.violet.opacity(0.14))
                                                )
                                        }
                                    }
                                }
                            }
                            if !item.notes.isEmpty {
                                labeled("备注") {
                                    Text(item.notes)
                                        .font(.system(size: 12.5))
                                        .foregroundStyle(Theme.text2)
                                        .textSelection(.enabled)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }

                GlassCard(cornerRadius: 18) {
                    VStack(spacing: 8) {
                        metaLine("创建时间", item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        metaLine("最近修改", item.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }

                Button {
                    showDeleteConfirm = true
                } label: {
                    Label("删除这条记录", systemImage: "trash")
                }
                .buttonStyle(GlassButtonStyle())
                .foregroundStyle(Color(hex: "#FF9AA5")!)

                Text("本机加密存储 · AES-256-GCM")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.text3)
                    .padding(.top, 4)
            }
        }
    }

    private func hero(_ item: VaultItem) -> some View {
        let category = session.category(item.categoryID)
        let brand = BrandLibrary.info(for: item, category: category)

        return VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(brand.color.opacity(0.35))
                    .frame(width: 150, height: 150)
                    .blur(radius: 42)

                BrandAvatarView(item: item, size: 76, brand: brand)
            }
            .frame(height: 150)

            Text(item.title)
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(Theme.titleGradient)

            HStack(spacing: 7) {
                Text(category.name)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.violet2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.violet.opacity(0.14)))
            }
        }
        .padding(.top, 4)
    }

    private func row<Actions: View>(
        symbol: String,
        label: String,
        value: String,
        mono: Bool,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.violet2)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Theme.text3)
                Text(value)
                    .font(.system(size: 15, design: mono ? .monospaced : .default))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 6)

            actions()
                .font(.system(size: 15, weight: .medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Theme.text3)
            content()
        }
    }

    private func metaLine(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.text3)
            Spacer()
            Text(value)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.text3)
        }
    }
}

// MARK: - 通用滚动容器

struct ZenScroll<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 40)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
        }
    }
}
