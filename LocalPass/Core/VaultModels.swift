import Foundation
import SwiftUI

// MARK: - 分类（可自定义）

struct VaultCategory: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var symbol: String        // SF Symbol 名
    var colorHex: String      // "#7C6CFF"
    var isBuiltin: Bool

    init(id: String, name: String, symbol: String, colorHex: String, isBuiltin: Bool = false) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.colorHex = colorHex
        self.isBuiltin = isBuiltin
    }

    private enum CodingKeys: String, CodingKey { case id, name, symbol, colorHex, isBuiltin }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "其他"
        symbol = try c.decodeIfPresent(String.self, forKey: .symbol) ?? "tray.full"
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex) ?? "#767A86"
        isBuiltin = try c.decodeIfPresent(Bool.self, forKey: .isBuiltin) ?? false
    }

    static let defaults: [VaultCategory] = [
        VaultCategory(id: "website", name: "网站", symbol: "globe", colorHex: "#3378F5", isBuiltin: true),
        VaultCategory(id: "app", name: "软件", symbol: "square.grid.2x2", colorHex: "#7059EB", isBuiltin: true),
        VaultCategory(id: "email", name: "邮箱", symbol: "envelope", colorHex: "#219E9E", isBuiltin: true),
        VaultCategory(id: "bank", name: "金融", symbol: "creditcard", colorHex: "#299957", isBuiltin: true),
        VaultCategory(id: "server", name: "服务器", symbol: "server.rack", colorHex: "#D98021", isBuiltin: true),
        VaultCategory(id: "other", name: "其他", symbol: "tray.full", colorHex: "#767A86", isBuiltin: true)
    ]

    static let fallback = VaultCategory(id: "other", name: "其他", symbol: "tray.full", colorHex: "#767A86", isBuiltin: true)

    var color: Color { Color(hex: colorHex) ?? .gray }
}

// MARK: - 单条账号

struct VaultItem: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var username: String
    var password: String
    var url: String
    var notes: String
    var categoryID: String
    var tags: [String]
    var isPinned: Bool
    /// 用户手动上传的图标（PNG，96×96）
    var customIcon: Data?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        username: String = "",
        password: String = "",
        url: String = "",
        notes: String = "",
        categoryID: String = "website",
        tags: [String] = [],
        isPinned: Bool = false,
        customIcon: Data? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.username = username
        self.password = password
        self.url = url
        self.notes = notes
        self.categoryID = categoryID
        self.tags = tags
        self.isPinned = isPinned
        self.customIcon = customIcon
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, username, password, url, notes
        case categoryID = "category"
        case categoryIDAlt = "categoryID"
        case tags, isPinned, customIcon, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        username = try c.decodeIfPresent(String.self, forKey: .username) ?? ""
        password = try c.decodeIfPresent(String.self, forKey: .password) ?? ""
        url = try c.decodeIfPresent(String.self, forKey: .url) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        customIcon = try c.decodeIfPresent(Data.self, forKey: .customIcon)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt

        // 兼容：老版本用 category，新版本可能用 categoryID
        if let v = try c.decodeIfPresent(String.self, forKey: .categoryID) {
            categoryID = v
        } else if let v = try c.decodeIfPresent(String.self, forKey: .categoryIDAlt) {
            categoryID = v
        } else {
            categoryID = "website"
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(username, forKey: .username)
        try c.encode(password, forKey: .password)
        try c.encode(url, forKey: .url)
        try c.encode(notes, forKey: .notes)
        try c.encode(categoryID, forKey: .categoryID)
        try c.encode(tags, forKey: .tags)
        try c.encode(isPinned, forKey: .isPinned)
        try c.encodeIfPresent(customIcon, forKey: .customIcon)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - 媒体

enum MediaKind: String, Codable {
    case image
    case video

    var title: String { self == .image ? "照片" : "视频" }
    var symbol: String { self == .image ? "photo" : "video.fill" }
}

struct VaultMedia: Codable, Identifiable, Hashable {
    var id: UUID
    var kind: MediaKind
    var name: String
    var mime: String
    var byteSize: Int
    var width: Int
    var height: Int
    var duration: Double
    /// 加密后的原始文件（Media 目录里的文件名）
    var file: String
    /// 缩略图（JPEG，随库一起加密，备份可带走）
    var thumb: Data?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        kind: MediaKind,
        name: String,
        mime: String,
        byteSize: Int,
        width: Int,
        height: Int,
        duration: Double = 0,
        file: String,
        thumb: Data? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.mime = mime
        self.byteSize = byteSize
        self.width = width
        self.height = height
        self.duration = duration
        self.file = file
        self.thumb = thumb
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, name, mime, byteSize, width, height, duration, file, thumb, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = MediaKind(rawValue: try c.decodeIfPresent(String.self, forKey: .kind) ?? "image") ?? .image
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "未命名"
        mime = try c.decodeIfPresent(String.self, forKey: .mime) ?? "image/jpeg"
        byteSize = try c.decodeIfPresent(Int.self, forKey: .byteSize) ?? 0
        width = try c.decodeIfPresent(Int.self, forKey: .width) ?? 0
        height = try c.decodeIfPresent(Int.self, forKey: .height) ?? 0
        duration = try c.decodeIfPresent(Double.self, forKey: .duration) ?? 0
        file = try c.decodeIfPresent(String.self, forKey: .file) ?? ""
        thumb = try c.decodeIfPresent(Data.self, forKey: .thumb)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    var sizeText: String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: Int64(byteSize))
    }

    var durationText: String {
        guard duration > 0 else { return "" }
        let m = Int(duration) / 60
        let s = Int(duration) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - 解密后的整库内容

struct VaultContent: Codable, Equatable {
    var version: Int
    var items: [VaultItem]
    var media: [VaultMedia]
    var categories: [VaultCategory]
    var updatedAt: Date

    init(
        version: Int = 2,
        items: [VaultItem] = [],
        media: [VaultMedia] = [],
        categories: [VaultCategory] = VaultCategory.defaults,
        updatedAt: Date = Date()
    ) {
        self.version = version
        self.items = items
        self.media = media
        self.categories = categories
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey { case version, items, media, categories, updatedAt }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        items = try c.decodeIfPresent([VaultItem].self, forKey: .items) ?? []
        media = try c.decodeIfPresent([VaultMedia].self, forKey: .media) ?? []
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()

        let cats = try c.decodeIfPresent([VaultCategory].self, forKey: .categories) ?? []
        if cats.isEmpty {
            categories = VaultCategory.defaults
        } else {
            // 保证内置分类始终存在
            var merged = cats
            for d in VaultCategory.defaults where !merged.contains(where: { $0.id == d.id }) {
                merged.append(d)
            }
            categories = merged
        }
    }

    func category(_ id: String) -> VaultCategory {
        categories.first { $0.id == id } ?? VaultCategory.fallback
    }

    var allTags: [String] {
        Array(Set(items.flatMap { $0.tags })).sorted()
    }
}

// MARK: - 文件头（加密容器，不含明文账号）

struct VaultHeader: Codable, Equatable {
    var formatVersion: Int
    var kdf: String
    var hint: String
    var wrappedKey: WrappedKey
    var gesture: WrappedKey?
    var biometric: Bool
    var payload: EncryptedPayload

    struct WrappedKey: Codable, Equatable {
        var algorithm: String
        var iterations: Int
        var salt: Data
        var cipher: Data
    }

    struct EncryptedPayload: Codable, Equatable {
        var algorithm: String
        var nonce: Data
        var cipher: Data
        var tag: Data
    }

    init(
        formatVersion: Int = 1,
        kdf: String = "PBKDF2-HMAC-SHA256",
        hint: String = "",
        wrappedKey: WrappedKey,
        gesture: WrappedKey? = nil,
        biometric: Bool = false,
        payload: EncryptedPayload
    ) {
        self.formatVersion = formatVersion
        self.kdf = kdf
        self.hint = hint
        self.wrappedKey = wrappedKey
        self.gesture = gesture
        self.biometric = biometric
        self.payload = payload
    }

    private enum CodingKeys: String, CodingKey {
        case formatVersion, kdf, hint, wrappedKey, gesture, biometric, payload
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try c.decodeIfPresent(Int.self, forKey: .formatVersion) ?? 1
        kdf = try c.decodeIfPresent(String.self, forKey: .kdf) ?? "PBKDF2-HMAC-SHA256"
        hint = try c.decodeIfPresent(String.self, forKey: .hint) ?? ""
        wrappedKey = try c.decode(WrappedKey.self, forKey: .wrappedKey)
        gesture = try c.decodeIfPresent(WrappedKey.self, forKey: .gesture)
        biometric = try c.decodeIfPresent(Bool.self, forKey: .biometric) ?? false
        payload = try c.decode(EncryptedPayload.self, forKey: .payload)
    }

    var hasGesture: Bool { gesture != nil }
}
