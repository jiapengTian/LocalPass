import Foundation
import Combine
import UIKit

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var symbol: String
}

enum VaultNotifications {
    static let didLock = Notification.Name("LocalPass.didLock")
}

// MARK: - 保险箱分区

enum VaultTab: String, CaseIterable, Identifiable {
    case passwords
    case media

    var id: String { rawValue }
    var title: String { self == .passwords ? "密码库" : "图片视频库" }
    var symbol: String { self == .passwords ? "key.fill" : "photo.on.rectangle" }
}

enum MediaFilter: String, CaseIterable, Identifiable {
    case all
    case image
    case video

    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "全部"
        case .image: return "照片"
        case .video: return "视频"
        }
    }
}

/// 导入前准备好的媒体（缩略图/元数据已算好）
struct PreparedMedia {
    var kind: MediaKind
    var name: String
    var mime: String
    var width: Int
    var height: Int
    var duration: Double
    var payload: Data
    var thumbnail: Data?
    var byteSize: Int
}

// MARK: - 会话

@MainActor
final class VaultSession: ObservableObject {

    enum Phase: Equatable {
        case loading
        case needSetup
        case locked
        case unlocked
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var content = VaultContent()
    @Published private(set) var header: VaultHeader?
    @Published private(set) var busy = false
    @Published private(set) var setupToken = UUID()
    @Published var toast: ToastMessage?
    @Published var tab: VaultTab = .passwords
    @Published var mediaFilter: MediaFilter = .all
    @Published var biometricStatus = Biometrics.Status(
        canUse: false,
        kind: "Face ID / Touch ID",
        isEnrolled: false,
        hasPasscode: false
    )

    let settings = AppSettings()
    let store = VaultStore()

    private var toastTask: Task<Void, Never>?
    private var clipboardTask: Task<Void, Never>?
    private let thumbnailCache = NSCache<NSString, UIImage>()

    private(set) var gestureSalt: Data?
    private static var hasPromptedBiometric = false

    // MARK: 启动

    func bootstrap() async {
        refreshBiometricStatus()
        let exists = await store.hasVault()
        if exists {
            header = await store.readHeader()
            phase = .locked
        } else {
            phase = .needSetup
        }
    }

    func refreshBiometricStatus() {
        biometricStatus = Biometrics.status()
    }

    var canOfferBiometric: Bool {
        guard let header else { return false }
        return header.biometric && settings.biometricEnabled && biometricStatus.canUse
    }

    // MARK: 首次创建

    func createVault(
        password: String,
        hint: String,
        gesturePattern: [Int]?,
        enableBiometrics: Bool
    ) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }

        refreshBiometricStatus()
        let wantBiometric = enableBiometrics && biometricStatus.canUse && biometricStatus.hasPasscode
        do {
            var initial = VaultContent()
            initial.categories = VaultCategory.defaults
            let result = try await store.create(
                password: password,
                hint: hint,
                gesturePattern: gesturePattern,
                enableBiometrics: wantBiometric,
                initialContent: initial
            )
            adopt(result)
            settings.biometricEnabled = result.header.biometric
            showToast(
                enableBiometrics && !result.header.biometric
                    ? "系统验证未能启用，已改用主密码解锁"
                    : "密码库已创建，数据只保存在本机",
                symbol: result.header.biometric ? "checkmark.shield" : "exclamationmark.triangle"
            )
        } catch {
            showToast(VaultStoreError.describe(error), symbol: "exclamationmark.triangle")
        }
    }

    // MARK: 解锁

    func unlock(password: String) async -> Bool {
        guard !password.isEmpty, !busy else { return false }
        busy = true
        defer { busy = false }
        do {
            let result = try await store.unlock(password: password)
            adopt(result)
            return true
        } catch {
            showToast(VaultStoreError.describe(error), symbol: "lock.trianglebadge.exclamationmark")
            return false
        }
    }

    func unlock(gesturePattern: [Int]) async -> Bool {
        guard !busy else { return false }
        busy = true
        defer { busy = false }
        do {
            let result = try await store.unlock(gesturePattern: gesturePattern)
            adopt(result)
            return true
        } catch {
            showToast("手势不正确", symbol: "hand.draw")
            return false
        }
    }

    func unlockWithBiometric() async -> Bool {
        guard !busy else { return false }
        busy = true
        defer { busy = false }
        do {
            let result = try await store.unlockWithBiometricKey()
            adopt(result)
            return true
        } catch {
            if KeychainError.isUserCancellation(error) { return false }
            header = await store.readHeader()
            if let storeError = error as? VaultStoreError, case .biometricNotEnabled = storeError {
                settings.biometricEnabled = false
                showToast("系统验证已失效，请改用主密码解锁", symbol: "exclamationmark.triangle")
            } else {
                showToast(VaultStoreError.describe(error), symbol: "exclamationmark.triangle")
            }
            return false
        }
    }

    func shouldAutoPromptBiometric() -> Bool {
        guard canOfferBiometric, !VaultSession.hasPromptedBiometric else { return false }
        VaultSession.hasPromptedBiometric = true
        return true
    }

    private func adopt(_ result: UnlockResult) {
        content = normalise(result.content)
        header = result.header
        gestureSalt = result.gestureSalt
        phase = .unlocked
        tab = .passwords
        mediaFilter = .all
        if result.header.biometric && !settings.biometricEnabled {
            settings.biometricEnabled = true
        }
    }

    private func normalise(_ input: VaultContent) -> VaultContent {
        var value = input
        if value.categories.isEmpty { value.categories = VaultCategory.defaults }
        let ids = Set(value.categories.map { $0.id })
        for index in value.items.indices where !ids.contains(value.items[index].categoryID) {
            value.items[index].categoryID = "other"
        }
        return value
    }

    // MARK: 锁定

    func lock() {
        guard phase == .unlocked else {
            if phase != .needSetup { phase = .locked }
            return
        }
        thumbnailCache.removeAllObjects()
        content = VaultContent()
        gestureSalt = nil
        phase = .locked
        tab = .passwords
        Task { await store.lock() }
        NotificationCenter.default.post(name: VaultNotifications.didLock, object: nil)
    }

    // MARK: 记录增删改

    func upsert(_ item: VaultItem) async {
        var updatedItem = item
        updatedItem.updatedAt = Date()
        var updated = content
        if let index = updated.items.firstIndex(where: { $0.id == updatedItem.id }) {
            updated.items[index] = updatedItem
        } else {
            updated.items.append(updatedItem)
        }
        await persist(updated)
    }

    func delete(_ item: VaultItem) async {
        var updated = content
        updated.items.removeAll { $0.id == item.id }
        await persist(updated)
    }

    func togglePin(_ item: VaultItem) async {
        guard var target = content.items.first(where: { $0.id == item.id }) else { return }
        target.isPinned.toggle()
        await upsert(target)
    }

    private func persist(_ newContent: VaultContent) async {
        do {
            let updatedHeader = try await store.save(content: newContent)
            var committed = newContent
            committed.updatedAt = Date()
            content = committed
            header = updatedHeader
        } catch {
            showToast(VaultStoreError.describe(error), symbol: "exclamationmark.triangle")
        }
    }

    // MARK: 分类

    func category(_ id: String) -> VaultCategory {
        content.category(id)
    }

    var sortedItems: [VaultItem] {
        content.items.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    var sortedMedia: [VaultMedia] {
        let list = content.media.filter { media in
            switch mediaFilter {
            case .all: return true
            case .image: return media.kind == .image
            case .video: return media.kind == .video
            }
        }
        return list.sorted { $0.createdAt > $1.createdAt }
    }

    func addCategory(name: String, symbol: String, colorHex: String) async {
        let category = VaultCategory(
            id: "cat-" + UUID().uuidString.prefix(8),
            name: name,
            symbol: symbol,
            colorHex: colorHex,
            isBuiltin: false
        )
        var updated = content
        updated.categories.append(category)
        await persist(updated)
        showToast("已添加分类「\(name)」", symbol: "checkmark")
    }

    func updateCategory(_ category: VaultCategory) async {
        var updated = content
        guard let index = updated.categories.firstIndex(where: { $0.id == category.id }) else { return }
        updated.categories[index] = category
        await persist(updated)
        showToast("已更新「\(category.name)」", symbol: "checkmark")
    }

    func deleteCategory(_ category: VaultCategory) async {
        guard !category.isBuiltin else {
            showToast("内置分类不能删除", symbol: "exclamationmark.triangle")
            return
        }
        var updated = content
        updated.categories.removeAll { $0.id == category.id }
        for index in updated.items.indices where updated.items[index].categoryID == category.id {
            updated.items[index].categoryID = "other"
        }
        await persist(updated)
        showToast("已删除分类", symbol: "trash")
    }

    // MARK: 媒体

    func importMedia(_ prepared: PreparedMedia) async -> Bool {
        guard !busy else { return false }
        busy = true
        defer { busy = false }

        do {
            let file = try await store.storeMediaFile(prepared.payload)
            let media = VaultMedia(
                kind: prepared.kind,
                name: prepared.name,
                mime: prepared.mime,
                byteSize: prepared.byteSize,
                width: prepared.width,
                height: prepared.height,
                duration: prepared.duration,
                file: file,
                thumb: prepared.thumbnail
            )
            var updated = content
            updated.media.append(media)
            await persist(updated)
            return true
        } catch {
            showToast(VaultStoreError.describe(error), symbol: "exclamationmark.triangle")
            return false
        }
    }

    func thumbnail(for media: VaultMedia) async -> UIImage? {
        if let cached = thumbnailCache.object(forKey: media.id.uuidString as NSString) {
            return cached
        }
        guard let data = media.thumb, let image = UIImage(data: data) else { return nil }
        thumbnailCache.setObject(image, forKey: media.id.uuidString as NSString)
        return image
    }

    func mediaData(for media: VaultMedia) async -> Data? {
        try? await store.loadMediaFile(media.file)
    }

    func deleteMedia(_ media: VaultMedia) async {
        thumbnailCache.removeObject(forKey: media.id.uuidString as NSString)
        var updated = content
        updated.media.removeAll { $0.id == media.id }
        await persist(updated)
        await store.deleteMediaFile(media.file)
        showToast("已删除", symbol: "trash")
    }

    // MARK: 主密码 / 手势 / 系统验证

    func changeMasterPassword(current: String, new: String) async -> Bool {
        do {
            let updatedHeader = try await store.changePassword(current: current, new: new)
            header = updatedHeader
            showToast("主密码已更新", symbol: "checkmark.shield")
            return true
        } catch {
            showToast(VaultStoreError.describe(error), symbol: "exclamationmark.triangle")
            return false
        }
    }

    func setGesture(_ pattern: [Int]) async -> Bool {
        do {
            let updatedHeader = try await store.setGesture(pattern)
            header = updatedHeader
            gestureSalt = updatedHeader.gesture?.salt
            showToast("手势解锁已更新", symbol: "hand.draw")
            return true
        } catch {
            showToast(VaultStoreError.describe(error), symbol: "exclamationmark.triangle")
            return false
        }
    }

    func disableGesture() async -> Bool {
        do {
            let updatedHeader = try await store.setGesture(nil)
            header = updatedHeader
            gestureSalt = nil
            showToast("已关闭手势解锁", symbol: "hand.draw")
            return true
        } catch {
            showToast(VaultStoreError.describe(error), symbol: "exclamationmark.triangle")
            return false
        }
    }

    func setBiometrics(_ enabled: Bool) async -> Bool {
        refreshBiometricStatus()
        if enabled && !biometricStatus.canUse {
            showToast(biometricStatus.unavailableMessage, symbol: "faceid")
            return false
        }
        do {
            let updatedHeader = try await store.setBiometrics(enabled)
            header = updatedHeader
            settings.biometricEnabled = updatedHeader.biometric
            showToast(enabled ? "已开启系统验证解锁" : "已关闭系统验证解锁", symbol: "faceid")
            return true
        } catch {
            showToast(VaultStoreError.describe(error), symbol: "exclamationmark.triangle")
            return false
        }
    }

    // MARK: 剪贴板

    func copyPassword(of item: VaultItem) {
        copy(item.password, label: "密码")
    }

    func copyUsername(of item: VaultItem) {
        copy(item.username, label: "账号")
    }

    func copy(_ value: String, label: String) {
        guard !value.isEmpty else { return }
        UIPasteboard.general.string = value
        showToast("\(label)已复制", symbol: "doc.on.doc")

        clipboardTask?.cancel()
        guard settings.clearClipboardEnabled else { return }
        let seconds = max(1, settings.clipboardClearSeconds)
        clipboardTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
            guard !Task.isCancelled else { return }
            if UIPasteboard.general.string == value {
                UIPasteboard.general.string = ""
                self?.showToast("剪贴板已自动清空", symbol: "clipboard")
            }
        }
    }

    // MARK: 备份 / 恢复 / 重置

    func exportBackup(password: String) async -> URL? {
        guard !busy else { return nil }
        busy = true
        defer { busy = false }
        do {
            let snapshot = try await store.exportContent()
            let data = try BackupService.makeBackupFileData(content: snapshot, password: password)
            let exportsURL = await store.exportsDirectoryURL
            try FileManager.default.createDirectory(at: exportsURL, withIntermediateDirectories: true)
            let url = exportsURL.appendingPathComponent(BackupService.suggestedFileName())
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            showToast("加密备份已生成", symbol: "square.and.arrow.up")
            return url
        } catch {
            showToast(VaultStoreError.describe(error), symbol: "exclamationmark.triangle")
            return nil
        }
    }

    func importBackup(data: Data, password: String) async -> Bool {
        guard !busy else { return false }
        busy = true
        defer { busy = false }
        do {
            let restored = try BackupService.restore(data: data, password: password)
            let (updatedHeader, applied) = try await store.replaceContent(restored)
            content = normalise(applied)
            header = updatedHeader
            showToast("已恢复 \(applied.items.count) 条记录", symbol: "arrow.down.doc")
            return true
        } catch {
            showToast(VaultStoreError.describe(error), symbol: "exclamationmark.triangle")
            return false
        }
    }

    /// 忘记主密码：用备份 + 新主密码重建整个库
    func restoreFromBackup(data: Data, backupPassword: String, newPassword: String) async -> Bool {
        guard !busy else { return false }
        busy = true
        defer { busy = false }
        do {
            var restored = try BackupService.restore(data: data, password: backupPassword)
            if restored.categories.isEmpty { restored.categories = VaultCategory.defaults }
            let result = try await store.create(
                password: newPassword,
                hint: "",
                gesturePattern: nil,
                enableBiometrics: false,
                initialContent: restored
            )
            adopt(result)
            settings.biometricEnabled = false
            showToast("已用备份重建密码库", symbol: "checkmark.shield")
            return true
        } catch {
            showToast(VaultStoreError.describe(error), symbol: "exclamationmark.triangle")
            return false
        }
    }

    func eraseEverything() async {
        await store.deleteEverything()
        AppSettings.resetAll()
        settings.biometricEnabled = false
        content = VaultContent()
        header = nil
        gestureSalt = nil
        setupToken = UUID()
        phase = .needSetup
        NotificationCenter.default.post(name: VaultNotifications.didLock, object: nil)
    }

    // MARK: 自检

    func diagnosticsText() -> String {
        var lines: [String] = []
        let f = header
        lines.append("库文件：" + (f == nil ? "缺失" : "存在"))
        if let f {
            lines.append("格式版本：\(f.formatVersion)")
            lines.append("KDF：\(f.kdf)，迭代 \(f.wrappedKey.iterations) 轮")
            lines.append("salt：\(f.wrappedKey.salt.count) 字节")
            lines.append("密文：\(f.wrappedKey.cipher.count) 字节（应为 60 = 12+32+16）")
            lines.append("数据段：\(f.payload.cipher.count) 字节")
            lines.append("手势：\(f.hasGesture ? "已设置" : "未设置")")
            lines.append("系统验证：\(f.biometric ? "已注册" : "未注册")")
            lines.append("提示：\(f.hint.isEmpty ? "未设置" : f.hint)")
        }
        lines.append("记录：\(content.items.count) 条，媒体：\(content.media.count) 个")
        lines.append("系统验证可用：\(biometricStatus.canUse ? "是" : "否")（\(biometricStatus.kind)）")
        return lines.joined(separator: "\n")
    }

    // MARK: 提示

    func showToast(_ text: String, symbol: String = "info.circle") {
        toastTask?.cancel()
        let message = ToastMessage(text: text, symbol: symbol)
        toast = message
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if self?.toast?.id == message.id { self?.toast = nil }
            }
        }
    }

    func dismissToast() {
        toastTask?.cancel()
        toast = nil
    }

    // MARK: 统计

    var itemCount: Int { content.items.count }
    var mediaCount: Int { content.media.count }
    var photoCount: Int { content.media.filter { $0.kind == .image }.count }
    var videoCount: Int { content.media.filter { $0.kind == .video }.count }
    var allTags: [String] { content.allTags }

    func item(withID id: UUID) -> VaultItem? {
        content.items.first { $0.id == id }
    }

    var biometricKindName: String {
        biometricStatus.canUse ? biometricStatus.kind : "Face ID"
    }
}
