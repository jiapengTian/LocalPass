import SwiftUI
import PhotosUI
import UIKit

// MARK: - 新建 / 编辑

struct ItemEditorView: View {
    enum Mode {
        case create
        case edit(VaultItem)

        var original: VaultItem? {
            if case .edit(let item) = self { return item }
            return nil
        }

        var isCreate: Bool {
            if case .create = self { return true }
            return false
        }
    }

    @ObservedObject var session: VaultSession
    let mode: Mode
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var username = ""
    @State private var password = ""
    @State private var url = ""
    @State private var notes = ""
    @State private var categoryID = "website"
    @State private var selectedTags: Set<String> = []
    @State private var newTag = ""
    @State private var isPinned = false
    @State private var customIcon: Data?
    @State private var showPassword = false
    @State private var iconItem: PhotosPickerItem?
    @State private var saving = false
    @State private var showCategoryEditor = false

    init(session: VaultSession, mode: Mode) {
        self.session = session
        self.mode = mode
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool { !trimmedTitle.isEmpty && !saving }

    private var allTags: [String] {
        Array(Set(session.allTags + Array(selectedTags))).sorted()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        headerRow

                        sectionTitle("基本信息")
                        GlassCard(cornerRadius: 16, padding: 14) {
                            HStack(spacing: 12) {
                                VStack(spacing: 6) {
                                    BrandAvatarView(
                                        item: previewItem,
                                        size: 54,
                                        brand: BrandLibrary.info(
                                            for: previewItem,
                                            category: session.category(categoryID)
                                        )
                                    )
                                    PhotosPicker(selection: $iconItem, matching: .images) {
                                        Text("上传")
                                            .font(.system(size: 10.5, weight: .semibold))
                                            .foregroundStyle(Theme.violet2)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 3)
                                            .background(Capsule().fill(Theme.violet.opacity(0.14)))
                                    }
                                    if customIcon != nil {
                                        Button("清除") { customIcon = nil }
                                            .font(.system(size: 10.5))
                                            .foregroundStyle(Theme.text3)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    TextField("名称，例如：淘宝", text: $title)
                                        .font(.system(size: 15))
                                        .foregroundStyle(Theme.text)
                                        .autocorrectionDisabled()
                                    Text(iconHint)
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(Theme.text3)
                                }
                                Spacer(minLength: 0)
                            }
                        }

                        sectionTitle("账号与密码")
                        GlassCard(cornerRadius: 16, padding: 14) {
                            VStack(spacing: 10) {
                                TextField("账号 / 用户名 / 邮箱", text: $username)
                                    .modifier(EditorFieldStyle())
                                    .textContentType(.username)

                                HStack(spacing: 8) {
                                    Group {
                                        if showPassword {
                                            TextField("密码", text: $password)
                                        } else {
                                            SecureField("密码", text: $password)
                                        }
                                    }
                                    .modifier(EditorFieldStyle())

                                    Button {
                                        showPassword.toggle()
                                    } label: {
                                        Image(systemName: showPassword ? "eye.slash" : "eye")
                                    }
                                    .buttonStyle(IconButtonStyle(size: 44))
                                }

                                if !password.isEmpty {
                                    StrengthBar(password: password)
                                }

                                TextField("网址（可选，用来自动识别图标）", text: $url)
                                    .modifier(EditorFieldStyle())
                                    .keyboardType(.URL)
                            }
                        }

                        sectionTitle("分类")
                        GlassCard(cornerRadius: 16, padding: 14) {
                            VStack(alignment: .leading, spacing: 10) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(session.content.categories) { category in
                                            Button {
                                                categoryID = category.id
                                            } label: {
                                                Text(category.name)
                                            }
                                            .buttonStyle(PillStyle(selected: categoryID == category.id))
                                        }
                                        Button {
                                            showCategoryEditor = true
                                        } label: {
                                            Label("新分类", systemImage: "plus")
                                        }
                                        .buttonStyle(DashedPillStyle())
                                    }
                                }
                            }
                        }

                        sectionTitle("标签")
                        GlassCard(cornerRadius: 16, padding: 14) {
                            VStack(alignment: .leading, spacing: 10) {
                                if allTags.isEmpty {
                                    Text("还没有标签，输入后可在所有记录里复用")
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(Theme.text3)
                                } else {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(allTags, id: \.self) { tag in
                                                Button {
                                                    if selectedTags.contains(tag) {
                                                        selectedTags.remove(tag)
                                                    } else {
                                                        selectedTags.insert(tag)
                                                    }
                                                } label: {
                                                    Text("#\(tag)")
                                                }
                                                .buttonStyle(PillStyle(selected: selectedTags.contains(tag)))
                                            }
                                        }
                                    }
                                }

                                HStack(spacing: 8) {
                                    TextField("输入新标签", text: $newTag)
                                        .modifier(EditorFieldStyle())
                                    Button("添加") { addTag() }
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Theme.violet2)
                                        .frame(width: 58, height: 44)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Theme.surface2)
                                        )
                                }
                            }
                        }

                        sectionTitle("备注")
                        GlassCard(cornerRadius: 16, padding: 14) {
                            TextEditor(text: $notes)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.text)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 90)
                        }

                        GlassCard(cornerRadius: 16, padding: 14) {
                            Toggle(isOn: $isPinned) {
                                Text("置顶显示")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.text)
                            }
                            .tint(Theme.mint)
                        }
                        .padding(.top, 14)

                        Text("所有字段都会加密写入本机文件，不会发送到任何服务器。")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.text3)
                            .padding(.top, 14)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(mode.isCreate ? "新增账号" : "编辑账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(Theme.text2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving {
                        ProgressView().tint(Theme.violet2)
                    } else {
                        Button("保存") { save() }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(canSave ? Theme.violet2 : Theme.text3)
                            .disabled(!canSave)
                    }
                }
            }
            .sheet(isPresented: $showCategoryEditor) {
                CategoryEditorView(session: session, category: nil)
            }
            .task {
                loadInitialValues()
            }
            .onChange(of: iconItem) { item in
                guard let item else { return }
                Task { await loadIcon(item) }
            }
            .onReceive(NotificationCenter.default.publisher(for: VaultNotifications.didLock)) { _ in
                dismiss()
            }
        }
    }

    // MARK: 部件

    private var previewItem: VaultItem {
        VaultItem(
            id: mode.original?.id ?? UUID(),
            title: title,
            url: url,
            categoryID: categoryID,
            customIcon: customIcon
        )
    }

    private var iconHint: String {
        if customIcon != nil { return "使用自定义图标（随库加密保存）" }
        let domain = BrandLibrary.domain(of: url)
        if !domain.isEmpty { return "按网址读取图标：\(domain)" }
        return "填写网址后自动识别图标，或手动上传"
    }

    private var headerRow: some View {
        EmptyView()
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.1)
            .foregroundStyle(Theme.text3)
            .padding(.top, 18)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 数据

    private func loadInitialValues() {
        guard let item = mode.original else {
            if let first = session.content.categories.first { categoryID = first.id }
            return
        }
        title = item.title
        username = item.username
        password = item.password
        url = item.url
        notes = item.notes
        categoryID = item.categoryID
        selectedTags = Set(item.tags)
        isPinned = item.isPinned
        customIcon = item.customIcon
    }

    private func addTag() {
        let parts = newTag
            .components(separatedBy: CharacterSet(charactersIn: ",，# \n\t"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        for part in parts { selectedTags.insert(part) }
        newTag = ""
    }

    @MainActor
    private func loadIcon(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            session.showToast("这个图片读不出来", symbol: "exclamationmark.triangle")
            return
        }
        customIcon = IconRenderer.squareIcon(from: image, side: 96)
    }

    private func save() {
        guard canSave else { return }
        saving = true
        addTag()

        var item = mode.original ?? VaultItem()
        item.title = trimmedTitle
        item.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        item.password = password
        item.url = url.trimmingCharacters(in: .whitespacesAndNewlines)
        item.notes = notes
        item.categoryID = categoryID
        item.tags = Array(selectedTags)
        item.isPinned = isPinned
        item.customIcon = customIcon
        item.updatedAt = Date()

        Task {
            await session.upsert(item)
            saving = false
            dismiss()
        }
    }
}

// MARK: - 输入框样式

struct EditorFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 14.5))
            .foregroundStyle(Theme.text)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .padding(.horizontal, 13)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
    }
}

// MARK: - 强度条

struct StrengthBar: View {
    var password: String

    private var strength: PasswordStrength { PasswordStrength.evaluate(password) }

    private var color: Color {
        switch strength {
        case .weak: return Color(hex: "#D63A3A")!
        case .fair: return Theme.amber
        case .good: return Color(hex: "#C9A227")!
        case .strong: return Theme.mint
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index <= strength.rawValue ? color : Color.white.opacity(0.1))
                    .frame(height: 4)
            }
            Text(strength.title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 34, alignment: .trailing)
        }
        .animation(.easeOut(duration: 0.2), value: strength)
    }
}

// MARK: - 图标裁切

enum IconRenderer {
    static func squareIcon(from image: UIImage, side: CGFloat) -> Data? {
        let target = CGSize(width: side, height: side)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let output = renderer.image { _ in
            let sourceSide = min(image.size.width, image.size.height)
            guard sourceSide > 0 else { return }
            let scale = side / sourceSide
            let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let offsetX = (image.size.width - sourceSide) / 2 * scale
            let offsetY = (image.size.height - sourceSide) / 2 * scale
            image.draw(in: CGRect(x: -offsetX, y: -offsetY, width: drawSize.width, height: drawSize.height))
        }
        return output.pngData()
    }
}
