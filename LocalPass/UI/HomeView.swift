import SwiftUI
import AVKit
import PhotosUI
import UIKit

// MARK: - 首页（双保险箱）

struct HomeView: View {
    @ObservedObject var session: VaultSession

    @State private var searchText = ""
    @State private var filterCategory: String?
    @State private var filterTag: String?
    @State private var route: Route?
    @State private var pendingDelete: VaultItem?
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showPicker = false
    @State private var importing = false

    enum Route: Identifiable {
        case create
        case edit(VaultItem)
        case detail(UUID)
        case category(VaultCategory?)
        case settings
        case media(VaultMedia)

        var id: String {
            switch self {
            case .create: return "create"
            case .edit(let item): return "edit-\(item.id.uuidString)"
            case .detail(let id): return "detail-\(id.uuidString)"
            case .category(let category): return "cat-\(category?.id ?? "new")"
            case .settings: return "settings"
            case .media(let media): return "media-\(media.id.uuidString)"
            }
        }
    }

    var body: some View {
        ZStack {
            AuroraBackground()

            VStack(spacing: 0) {
                heroHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                vaultTabs
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                if session.tab == .passwords {
                    passwordPane
                } else {
                    mediaPane
                }
            }
        }
        .sheet(item: $route) { route in
            switch route {
            case .create:
                ItemEditorView(session: session, mode: .create)
            case .edit(let item):
                ItemEditorView(session: session, mode: .edit(item))
            case .detail(let id):
                NavigationStack {
                    VaultItemDetailView(session: session, itemID: id)
                }
            case .category(let category):
                CategoryEditorView(session: session, category: category)
                    .presentationDetents([.large])
            case .settings:
                SettingsView(session: session)
                    .environmentObject(session.settings)
            case .media(let media):
                MediaViewerView(session: session, media: media)
            }
        }
        .confirmationDialog(
            "删除「\(pendingDelete?.title ?? "")」？",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let target = pendingDelete {
                    pendingDelete = nil
                    Task { await session.delete(target) }
                }
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        }
        .photosPicker(
            isPresented: $showPicker,
            selection: $pickerItems,
            maxSelectionCount: 12,
            matching: .any(of: [.images, .videos])
        )
        .onChange(of: pickerItems) { items in
            guard !items.isEmpty else { return }
            Task { await importPicked(items) }
        }
        .onReceive(NotificationCenter.default.publisher(for: VaultNotifications.didLock)) { _ in
            route = nil
                    }
    }

    // MARK: 头部

    private var heroHeader: some View {
        GlassCard(cornerRadius: 24, padding: 16) {
            VStack(spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(Theme.brandGradient)
                        Image(systemName: session.tab == .passwords ? "shield.lefthalf.filled" : "photo.on.rectangle.angled")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 52, height: 52)
                    .shadow(color: Theme.violet.opacity(0.6), radius: 16, x: 0, y: 8)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("本地保险箱")
                            .font(.system(size: 10.5, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(Theme.text3)
                        Text(session.tab.title)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Theme.titleGradient)
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.text2)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    VStack(spacing: 8) {
                        Button {
                            route = .settings
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .buttonStyle(IconButtonStyle(size: 38))

                        if session.tab == .passwords {
                            Button {
                                route = .create
                            } label: {
                                Image(systemName: "plus")
                            }
                            .buttonStyle(IconButtonStyle(accent: true, size: 38))
                        } else {
                            Button {
                                showPicker = true
                            } label: {
                                Image(systemName: "square.and.arrow.down")
                            }
                            .buttonStyle(IconButtonStyle(accent: true, size: 38))
                        }
                    }
                }

                HStack(spacing: 8) {
                    StatPill(symbol: "key.fill", value: "\(session.itemCount)", label: "条账号记录")
                    StatPill(symbol: "photo.fill", value: "\(session.mediaCount)", label: "个媒体文件")
                }
            }
        }
    }

    private var subtitle: String {
        if session.tab == .passwords {
            return session.itemCount == 0 ? "还没有记录 · 只存本机" : "共 \(session.itemCount) 条记录 · 只存本机"
        }
        if session.mediaCount == 0 { return "照片和视频会被加密保存在本机" }
        return "共 \(session.mediaCount) 个文件 · \(session.photoCount) 张照片 · \(session.videoCount) 个视频"
    }

    // MARK: 分区切换

    private var vaultTabs: some View {
        HStack(spacing: 4) {
            ForEach(VaultTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        session.tab = tab
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 13, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 13.5, weight: .semibold))
                    }
                    .foregroundStyle(session.tab == tab ? Color.white : Theme.text2)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(session.tab == tab ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Color.clear))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }

    // MARK: 密码面板

    private var passwordPane: some View {
        VStack(spacing: 0) {
            categoryChips
                .padding(.top, 12)

            if !availableTags.isEmpty {
                tagChips
                    .padding(.top, 6)
            }

            searchBar
                .padding(.horizontal, 20)
                .padding(.top, 10)

            if filteredItems.isEmpty {
                emptyPasswordState
            } else {
                ScrollView {
                    LazyVStack(spacing: 9) {
                        ForEach(filteredItems) { item in
                            passwordRow(item)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 120)
                }
            }
        }
    }

    private var filteredItems: [VaultItem] {
        var list = session.content.items
        if let category = filterCategory {
            list = list.filter { $0.categoryID == category }
        }
        if let tag = filterTag {
            list = list.filter { $0.tags.contains(tag) }
        }
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !keyword.isEmpty {
            list = list.filter { item in
                item.title.lowercased().contains(keyword)
                    || item.username.lowercased().contains(keyword)
                    || item.url.lowercased().contains(keyword)
                    || item.notes.lowercased().contains(keyword)
                    || item.tags.contains { $0.lowercased().contains(keyword) }
            }
        }
        return list.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private var availableTags: [String] {
        var tags = Set(session.content.items.flatMap { $0.tags })
        if let tag = filterTag { tags.insert(tag) }
        return tags.sorted()
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    filterCategory = nil
                } label: {
                    Text("全部")
                }
                .buttonStyle(PillStyle(selected: filterCategory == nil))

                ForEach(session.content.categories) { category in
                    Button {
                        filterCategory = filterCategory == category.id ? nil : category.id
                    } label: {
                        Text(category.name)
                    }
                    .buttonStyle(PillStyle(selected: filterCategory == category.id))
                    .onLongPressGesture(minimumDuration: 0.45) {
                        route = .category(category)
                    }
                }

                Button {
                    route = .category(nil)
                } label: {
                    Label("分类", systemImage: "plus")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(DashedPillStyle())
            }
            .padding(.horizontal, 20)
        }
    }

    private var tagChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableTags, id: \.self) { tag in
                    Button {
                        filterTag = filterTag == tag ? nil : tag
                    } label: {
                        Text("#\(tag)")
                    }
                    .buttonStyle(PillStyle(selected: filterTag == tag))
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.text3)
            TextField("搜索名称、账号、标签", text: $searchText)
                .font(.system(size: 14.5))
                .foregroundStyle(Theme.text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }

    private func passwordRow(_ item: VaultItem) -> some View {
        let category = session.category(item.categoryID)
        let brand = BrandLibrary.info(for: item, category: category)

        return HStack(spacing: 13) {
            BrandAvatarView(item: item, size: 42, brand: brand)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if item.isPinned {
                        Circle().fill(Theme.amber).frame(width: 6, height: 6)
                    }
                    Text(item.title)
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                }
                Text(item.username.isEmpty ? "未填写账号" : item.username)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.text2)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Button {
                session.copyPassword(of: item)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 15, weight: .medium))
            }
            .buttonStyle(IconButtonStyle(size: 38))
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.cardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 14, x: 0, y: 8)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            route = .detail(item.id)
        }
        .contextMenu {
            Button {
                Task { await session.togglePin(item) }
            } label: {
                Label(item.isPinned ? "取消置顶" : "置顶", systemImage: item.isPinned ? "pin.slash" : "pin")
            }
            Button {
                session.copyUsername(of: item)
            } label: {
                Label("复制账号", systemImage: "person.text.rectangle")
            }
            Button {
                route = .edit(item)
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            Button(role: .destructive) {
                pendingDelete = item
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private var emptyPasswordState: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 30)
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.violet.opacity(0.24), Theme.cyan.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: session.itemCount == 0 ? "lock.rectangle.stack" : "magnifyingglass")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Theme.violet2)
            }
            .frame(width: 86, height: 86)

            Text(session.itemCount == 0 ? "还没有任何记录" : "没有找到匹配的记录")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.text)

            Text(session.itemCount == 0
                 ? "点右上角的 + ，把账号密码存进来。\n所有数据只保存在这台设备上。"
                 : "换个关键词，或者清除筛选条件试试。")
                .font(.system(size: 13))
                .foregroundStyle(Theme.text2)
                .multilineTextAlignment(.center)

            if session.itemCount == 0 {
                Button("添加第一条") {
                    route = .create
                }
                .buttonStyle(GlassButtonStyle())
                .frame(maxWidth: 200)
            }
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    // MARK: 媒体面板

    private var mediaPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 3) {
                    ForEach(MediaFilter.allCases) { filter in
                        Button {
                            session.mediaFilter = filter
                        } label: {
                            Text(filter.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(session.mediaFilter == filter ? Theme.text : Theme.text3)
                                .frame(maxWidth: .infinity)
                                .frame(height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(session.mediaFilter == filter ? Theme.surface3 : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Theme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )

                Button {
                    showPicker = true
                } label: {
                    Label("导入", systemImage: "square.and.arrow.down")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(DashedPillStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            if importing {
                HStack(spacing: 10) {
                    ProgressView().tint(Theme.violet2)
                    Text("正在加密并保存…")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.text2)
                }
                .padding(.top, 14)
            }

            if session.sortedMedia.isEmpty {
                VStack(spacing: 14) {
                    Spacer(minLength: 26)
                    ZStack {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Theme.violet.opacity(0.24), Theme.cyan.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(Theme.violet2)
                    }
                    .frame(width: 82, height: 82)

                    Text(session.mediaCount == 0 ? "还没有照片或视频" : "这个筛选下没有内容")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.text)

                    Text(session.mediaCount == 0
                         ? "导入后会被加密保存在本机，\n不会上传到任何服务器。"
                         : "切换到「全部」看看。")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.text2)
                        .multilineTextAlignment(.center)

                    if session.mediaCount == 0 {
                        Button("选择照片 / 视频") { showPicker = true }
                            .buttonStyle(GlassButtonStyle())
                            .frame(maxWidth: 220)
                    }
                    Spacer()
                }
                .padding(.horizontal, 28)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 104), spacing: 7)],
                        spacing: 7
                    ) {
                        ForEach(session.sortedMedia) { media in
                            MediaCell(session: session, media: media) {
                                route = .media(media)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }
            }
        }
    }

    // MARK: 导入

    @MainActor
    private func importPicked(_ items: [PhotosPickerItem]) async {
        importing = true
        var success = 0
        for item in items {
            if let prepared = await MediaImporter.prepare(from: item) {
                if await session.importMedia(prepared) { success += 1 }
            }
        }
        importing = false
        pickerItems = []
        if success > 0 {
            session.showToast("已加密保存 \(success) 个文件", symbol: "checkmark.shield")
        } else {
            session.showToast("没有可导入的内容", symbol: "exclamationmark.triangle")
        }
    }
}

// MARK: - 媒体格子

struct MediaCell: View {
    @ObservedObject var session: VaultSession
    var media: VaultMedia
    var onOpen: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: onOpen) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.07), Color.white.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: media.kind.symbol)
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(Theme.text3)
                }

                if media.kind == .video {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white.opacity(0.92))
                        .shadow(color: .black.opacity(0.5), radius: 6)
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(media.kind == .video ? media.durationText : media.sizeText)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(Color.black.opacity(0.55))
                            )
                    }
                }
                .padding(6)
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .task(id: media.id) {
            thumbnail = await session.thumbnail(for: media)
        }
    }
}

// MARK: - 媒体查看器

struct MediaViewerView: View {
    @ObservedObject var session: VaultSession
    var media: VaultMedia

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var player: AVPlayer?
    @State private var tempURL: URL?
    @State private var loading = true
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(IconButtonStyle(size: 38))

                    Spacer()

                    Text(media.name)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.text2)
                        .lineLimit(1)

                    Spacer()

                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(IconButtonStyle(size: 38))
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)

                Spacer(minLength: 0)

                Group {
                    if loading {
                        ProgressView().tint(.white)
                    } else if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    } else if let player {
                        VideoPlayer(player: player)
                            .aspectRatio(media.width > 0 && media.height > 0
                                         ? CGFloat(media.width) / CGFloat(media.height)
                                         : 16.0 / 9.0,
                                         contentMode: .fit)
                    } else {
                        Text("无法解密这个文件")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.text2)
                    }
                }
                .padding(.horizontal, 10)

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Image(systemName: media.kind.symbol)
                    Text(media.kind.title)
                    Text("·")
                    Text(media.sizeText)
                    if media.kind == .video, !media.durationText.isEmpty {
                        Text("·")
                        Text(media.durationText)
                    }
                }
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.text3)
                .padding(.bottom, 24)
            }
        }
        .task { await load() }
        .onDisappear {
            player?.pause()
            if let tempURL { try? FileManager.default.removeItem(at: tempURL) }
        }
        .confirmationDialog("删除这个文件？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                Task {
                    await session.deleteMedia(media)
                    dismiss()
                }
            }
            Button("取消", role: .cancel) {}
        }
    }

    @MainActor
    private func load() async {
        loading = true
        defer { loading = false }
        guard let data = await session.mediaData(for: media) else { return }

        if media.kind == .image {
            image = UIImage(data: data)
        } else {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(media.id.uuidString + ".mov")
            try? data.write(to: url, options: .atomic)
            tempURL = url
            player = AVPlayer(url: url)
            player?.play()
        }
    }
}
