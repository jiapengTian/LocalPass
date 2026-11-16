import SwiftUI

// MARK: - 分类编辑

struct CategoryEditorView: View {
    @ObservedObject var session: VaultSession
    var category: VaultCategory?

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var symbol = "tray.full"
    @State private var colorHex = "#7C6CFF"
    @State private var showDeleteConfirm = false
    @State private var saving = false

    private var isNew: Bool { category == nil }
    private var builtin: Bool { category?.isBuiltin == true }

    private static let symbols: [String] = [
        "globe", "square.grid.2x2", "envelope", "creditcard", "server.rack", "tray.full",
        "gamecontroller", "music.note", "cart", "building.columns", "book", "doc.text",
        "bubble.left", "cloud", "house", "gearshape", "film", "camera", "shield.lefthalf.filled", "star"
    ]

    private static let colors: [String] = [
        "#3378F5", "#7059EB", "#219E9E", "#299957", "#D98021",
        "#D64B7B", "#6B7A2F", "#B05A1E", "#5A6B8C", "#8E5AC8"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 14) {
                            preview
                            VStack(alignment: .leading, spacing: 6) {
                                Text("名称")
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundStyle(Theme.text3)
                                TextField("例如：游戏", text: $name)
                                    .modifier(EditorFieldStyle())
                            }
                        }
                        .padding(.top, 8)

                        sectionTitle("图标")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Self.symbols, id: \.self) { item in
                                    Button {
                                        symbol = item
                                    } label: {
                                        Image(systemName: item)
                                            .font(.system(size: 17, weight: .medium))
                                            .foregroundStyle(symbol == item ? Color.white : Theme.text2)
                                            .frame(width: 42, height: 42)
                                            .background(
                                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                                    .fill(symbol == item ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Theme.surface))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }

                        sectionTitle("颜色")
                        HStack(spacing: 12) {
                            ForEach(Self.colors, id: \.self) { hex in
                                Button {
                                    colorHex = hex
                                } label: {
                                    Circle()
                                        .fill(Color(hex: hex) ?? Theme.violet)
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(
                                                    colorHex == hex ? Color.white : Color.clear,
                                                    lineWidth: 2
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !isNew {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Label("删除这个分类", systemImage: "trash")
                            }
                            .buttonStyle(GlassButtonStyle())
                            .foregroundStyle(Color(hex: "#FF9AA5")!)
                            .padding(.top, 22)
                            .disabled(builtin)
                            .opacity(builtin ? 0.4 : 1)

                            Text(builtin ? "内置分类不能删除，但可以改名和换图标。" : "删除后，其中的记录会归到「其他」。")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.text3)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle(isNew ? "新增分类" : "编辑分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(Theme.violet2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving {
                        ProgressView().tint(Theme.violet2)
                    } else {
                        Button("保存") { save() }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.violet2)
                    }
                }
            }
            .alert("删除分类？", isPresented: $showDeleteConfirm) {
                Button("删除", role: .destructive) {
                    Task {
                        if let category {
                            await session.deleteCategory(category)
                        }
                        dismiss()
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("其中的记录会归到「其他」，记录本身不会丢失。")
            }
            .task {
                if let category {
                    name = category.name
                    symbol = category.symbol
                    colorHex = category.colorHex
                } else {
                    name = ""
                    symbol = Self.symbols[0]
                    colorHex = Self.colors[session.content.categories.count % Self.colors.count]
                }
            }
        }
    }

    private var preview: some View {
        Image(systemName: symbol)
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(Color(hex: colorHex) ?? Theme.violet)
            .frame(width: 58, height: 58)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill((Color(hex: colorHex) ?? Theme.violet).opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder((Color(hex: colorHex) ?? Theme.violet).opacity(0.4), lineWidth: 1)
            )
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.1)
            .foregroundStyle(Theme.text3)
            .padding(.top, 20)
            .padding(.bottom, 10)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            session.showToast("请输入分类名称", symbol: "exclamationmark.triangle")
            return
        }
        saving = true

        if var existing = category {
            existing.name = trimmed
            existing.symbol = symbol
            existing.colorHex = colorHex
            Task {
                await session.updateCategory(existing)
                saving = false
                dismiss()
            }
        } else {
            Task {
                await session.addCategory(name: trimmed, symbol: symbol, colorHex: colorHex)
                saving = false
                dismiss()
            }
        }
    }
}

// MARK: - 分类总览

struct CategoryListView: View {
    @ObservedObject var session: VaultSession
    @Environment(\.dismiss) private var dismiss
    @State private var target: EditTarget?

    /// 合并「编辑某个分类」和「新增分类」到一个弹层，避免两个 sheet 叠加。
    struct EditTarget: Identifiable {
        let id = UUID()
        var category: VaultCategory?
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(session.content.categories) { category in
                            Button {
                                target = EditTarget(category: category)
                            } label: {
                                HStack(spacing: 12) {
                                    CategoryBadge(category: category, size: 38)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(category.name)
                                            .font(.system(size: 14.5, weight: .semibold))
                                            .foregroundStyle(Theme.text)
                                        Text(category.isBuiltin
                                             ? "内置"
                                             : "\(count(for: category)) 条记录")
                                            .font(.system(size: 11.5))
                                            .foregroundStyle(Theme.text3)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Theme.text3)
                                }
                                .padding(13)
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

                        Button {
                            target = EditTarget(category: nil)
                        } label: {
                            Label("新增分类", systemImage: "plus")
                        }
                        .buttonStyle(GlassButtonStyle())
                        .padding(.top, 6)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("分类管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(Theme.violet2)
                }
            }
            .sheet(item: $target) { item in
                CategoryEditorView(session: session, category: item.category)
            }
        }
    }


    private func count(for category: VaultCategory) -> Int {
        session.content.items.filter { $0.categoryID == category.id }.count
    }
}
