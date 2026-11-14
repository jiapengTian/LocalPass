import Foundation

// MARK: - 错误

enum VaultStoreError: LocalizedError {
    case fileMissing
    case corruptedFile
    case vaultLocked
    case biometricNotEnabled
    case keychain(String)
    case passwordTooShort(Int)
    case passwordTooLong(Int)
    case fingerprintMismatch
    case mediaTooLarge(Int)
    case mediaUnreadable

    var errorDescription: String? {
        switch self {
        case .fileMissing: return "本机上还没有密码库。"
        case .corruptedFile: return "密码库文件无法读取，可能已损坏。"
        case .vaultLocked: return "密码库已锁定，请先解锁。"
        case .biometricNotEnabled: return "当前没有启用系统验证解锁。"
        case .keychain(let message): return message
        case .passwordTooShort(let minimum): return "主密码至少需要 \(minimum) 位。"
        case .passwordTooLong(let maximum): return "主密码不能超过 \(maximum) 位。"
        case .fingerprintMismatch: return "密码核对失败，请重试。"
        case .mediaTooLarge(let mb): return "单个文件不能超过 \(mb) MB。"
        case .mediaUnreadable: return "这个文件读不出来，可能格式不支持。"
        }
    }

    static func describe(_ error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}

// MARK: - 密码策略

enum VaultPolicy {
    static let minimumPasswordLength = 8
    static let maximumPasswordLength = 128
    static let minimumPatternDots = 4
    static let maximumMediaBytes = 300 * 1024 * 1024

    static func validatePassword(_ password: String) throws {
        if password.count < minimumPasswordLength {
            throw VaultStoreError.passwordTooShort(minimumPasswordLength)
        }
        if password.count > maximumPasswordLength {
            throw VaultStoreError.passwordTooLong(maximumPasswordLength)
        }
    }

    static func patternString(_ pattern: [Int]) -> String {
        pattern.map(String.init).joined(separator: "-")
    }
}

// MARK: - 解锁结果

struct UnlockResult {
    var header: VaultHeader
    var content: VaultContent
    var gestureSalt: Data?
}

// MARK: - 本地密码库

/// 所有落盘操作：一个加密 JSON + 一个原子备份 + Media 目录（媒体文件同样加密）。
actor VaultStore {

    let fileManager = FileManager.default

    private let applicationSupportURL: URL
    private let directoryName = "LocalPass"
    private let fileExtension = "vlt"

    private(set) var header: VaultHeader?
    private var vaultKey: Data?

    init(applicationSupportURL: URL? = nil) {
        if let applicationSupportURL {
            self.applicationSupportURL = applicationSupportURL
        } else {
            self.applicationSupportURL = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
        }
    }

    // MARK: 路径

    private var directoryURL: URL {
        applicationSupportURL.appendingPathComponent(directoryName, isDirectory: true)
    }

    var vaultURL: URL {
        directoryURL.appendingPathComponent("vault.\(fileExtension)")
    }

    private var backupURL: URL {
        directoryURL.appendingPathComponent("vault.\(fileExtension).bak")
    }

    var mediaDirectoryURL: URL {
        directoryURL.appendingPathComponent("Media", isDirectory: true)
    }

    var exportsDirectoryURL: URL {
        directoryURL.appendingPathComponent("Exports", isDirectory: true)
    }

    var isUnlocked: Bool { vaultKey != nil }

    // MARK: 基础读写

    private func ensureDirectory() throws {
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
    }

    private func ensureMediaDirectory() throws {
        try ensureDirectory()
        if !fileManager.fileExists(atPath: mediaDirectoryURL.path) {
            try fileManager.createDirectory(at: mediaDirectoryURL, withIntermediateDirectories: true)
        }
    }

    func readHeader() -> VaultHeader? {
        guard fileManager.fileExists(atPath: vaultURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: vaultURL)
            return try VaultCodec.decode(VaultHeader.self, from: data)
        } catch {
            return nil
        }
    }

    func hasVault() -> Bool {
        fileManager.fileExists(atPath: vaultURL.path)
    }

    private func persist(_ data: Data) throws {
        try ensureDirectory()
        let stagingURL = directoryURL.appendingPathComponent("vault.staging.\(UUID().uuidString)")
        try data.write(to: stagingURL, options: [.atomic, .completeFileProtection])

        if fileManager.fileExists(atPath: vaultURL.path) {
            try? fileManager.removeItem(at: backupURL)
            try? fileManager.copyItem(at: vaultURL, to: backupURL)
            _ = try fileManager.replaceItemAt(
                vaultURL,
                withItemAt: stagingURL,
                backupItemName: nil,
                options: [.usingNewMetadataOnly]
            )
        } else {
            try fileManager.moveItem(at: stagingURL, to: vaultURL)
        }

        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: vaultURL.path
        )
    }

    private func writeHeader() throws {
        guard let header else { throw VaultStoreError.vaultLocked }
        let data = try VaultCodec.encode(header)
        try persist(data)
    }

    // MARK: 密钥包装

    private func deriveKey(_ secret: String, salt: Data, iterations: Int) throws -> Data {
        try CryptoUtils.pbkdf2SHA256(password: secret, salt: salt, iterations: iterations, keyLength: 32)
    }

    private func makeWrapper(secret: String, key: Data, iterations: Int) throws -> VaultHeader.WrappedKey {
        let salt = try CryptoUtils.randomBytes(16)
        let derived = try deriveKey(secret, salt: salt, iterations: iterations)
        let box = try AESGCM.encrypt(key, key: derived)
        return VaultHeader.WrappedKey(
            algorithm: "AES-256-GCM",
            iterations: iterations,
            salt: salt,
            cipher: box.nonce + box.cipher + box.tag
        )
    }

    private func openWrapper(_ wrapper: VaultHeader.WrappedKey, secret: String) throws -> Data {
        let derived = try deriveKey(secret, salt: wrapper.salt, iterations: wrapper.iterations)
        let blob = wrapper.cipher
        guard blob.count > 12 + 16 else { throw VaultStoreError.corruptedFile }
        let nonce = blob.prefix(12)
        let tag = blob.suffix(16)
        let cipher = blob.dropFirst(12).dropLast(16)
        return try AESGCM.decrypt(cipher: cipher, nonce: nonce, tag: tag, key: derived)
    }

    private func encryptPayload(_ content: VaultContent, key: Data) throws -> VaultHeader.EncryptedPayload {
        let plaintext = try VaultCodec.encode(content)
        let box = try AESGCM.encrypt(plaintext, key: key)
        return VaultHeader.EncryptedPayload(
            algorithm: "AES-256-GCM",
            nonce: box.nonce,
            cipher: box.cipher,
            tag: box.tag
        )
    }

    private func decryptPayload(_ payload: VaultHeader.EncryptedPayload, key: Data) throws -> VaultContent {
        let plaintext = try AESGCM.decrypt(
            cipher: payload.cipher,
            nonce: payload.nonce,
            tag: payload.tag,
            key: key
        )
        do {
            return try VaultCodec.decode(VaultContent.self, from: plaintext)
        } catch {
            throw VaultStoreError.corruptedFile
        }
    }

    // MARK: 生命周期

    func create(
        password: String,
        hint: String,
        gesturePattern: [Int]?,
        enableBiometrics: Bool,
        initialContent: VaultContent
    ) async throws -> UnlockResult {
        try VaultPolicy.validatePassword(password)
        try ensureDirectory()

        let key = try CryptoUtils.randomBytes(32)
        let passwordWrapper = try makeWrapper(secret: password, key: key, iterations: KDFProfile.password)

        var gestureWrapper: VaultHeader.WrappedKey?
        if let pattern = gesturePattern, pattern.count >= VaultPolicy.minimumPatternDots {
            gestureWrapper = try makeWrapper(
                secret: VaultPolicy.patternString(pattern),
                key: key,
                iterations: KDFProfile.gesture
            )
        }

        let payload = try encryptPayload(initialContent, key: key)
        var finalHeader = VaultHeader(
            hint: hint,
            wrappedKey: passwordWrapper,
            gesture: gestureWrapper,
            biometric: false,
            payload: payload
        )

        if enableBiometrics {
            do {
                let applied = try VaultKeychain.save(key, userPresence: true)
                finalHeader.biometric = (applied == "userPresence")
            } catch {
                VaultKeychain.delete()
                finalHeader.biometric = false
            }
        }

        header = finalHeader
        vaultKey = key
        try writeHeader()

        return UnlockResult(
            header: finalHeader,
            content: initialContent,
            gestureSalt: finalHeader.gesture?.salt
        )
    }

    func unlock(password: String) async throws -> UnlockResult {
        guard let diskHeader = readHeader() else { throw VaultStoreError.fileMissing }
        let key = try openWrapper(diskHeader.wrappedKey, secret: password)
        let content = try decryptPayload(diskHeader.payload, key: key)
        header = diskHeader
        vaultKey = key
        return UnlockResult(header: diskHeader, content: content, gestureSalt: diskHeader.gesture?.salt)
    }

    func unlock(gesturePattern: [Int]) async throws -> UnlockResult {
        guard let diskHeader = readHeader() else { throw VaultStoreError.fileMissing }
        guard let wrapper = diskHeader.gesture else { throw VaultStoreError.corruptedFile }
        let key = try openWrapper(wrapper, secret: VaultPolicy.patternString(gesturePattern))
        let content = try decryptPayload(diskHeader.payload, key: key)
        header = diskHeader
        vaultKey = key
        return UnlockResult(header: diskHeader, content: content, gestureSalt: wrapper.salt)
    }

    func unlockWithBiometricKey() async throws -> UnlockResult {
        guard let diskHeader = readHeader() else { throw VaultStoreError.fileMissing }
        guard diskHeader.biometric else { throw VaultStoreError.biometricNotEnabled }

        guard let key = try VaultKeychain.load(reason: "验证身份以解锁密码库") else {
            try disableBiometrics()
            throw VaultStoreError.biometricNotEnabled
        }

        let content: VaultContent
        do {
            content = try decryptPayload(diskHeader.payload, key: key)
        } catch {
            try disableBiometrics()
            throw VaultStoreError.corruptedFile
        }

        header = diskHeader
        vaultKey = key
        return UnlockResult(header: diskHeader, content: content, gestureSalt: diskHeader.gesture?.salt)
    }

    func lock() {
        // 直接对存储属性就地清零（COW 只有在引用数为 1 时才真正写回内存）
        vaultKey?.withUnsafeMutableBytes { buffer in
            if let base = buffer.baseAddress {
                memset(base, 0, buffer.count)
            }
        }
        vaultKey = nil
        header = nil
    }

    // MARK: 保存

    func save(content: VaultContent) throws -> VaultHeader {
        guard let key = vaultKey, var current = header else { throw VaultStoreError.vaultLocked }
        var updated = content
        updated.updatedAt = Date()
        current.payload = try encryptPayload(updated, key: key)
        header = current
        try writeHeader()
        return current
    }

    func changePassword(current: String, new: String) async throws -> VaultHeader {
        guard let diskHeader = readHeader() else { throw VaultStoreError.fileMissing }
        try VaultPolicy.validatePassword(new)

        let oldKey = try openWrapper(diskHeader.wrappedKey, secret: current)
        if let sessionKey = vaultKey, !CryptoUtils.constantTimeEquals(sessionKey, oldKey) {
            throw VaultStoreError.fingerprintMismatch
        }

        var updated = diskHeader
        updated.wrappedKey = try makeWrapper(secret: new, key: oldKey, iterations: KDFProfile.password)
        header = updated
        vaultKey = oldKey
        try writeHeader()
        return updated
    }

    func setGesture(_ pattern: [Int]?) throws -> VaultHeader {
        guard let key = vaultKey, var current = header else { throw VaultStoreError.vaultLocked }
        if let pattern {
            guard pattern.count >= VaultPolicy.minimumPatternDots else { throw VaultStoreError.corruptedFile }
            current.gesture = try makeWrapper(
                secret: VaultPolicy.patternString(pattern),
                key: key,
                iterations: KDFProfile.gesture
            )
        } else {
            current.gesture = nil
        }
        header = current
        try writeHeader()
        return current
    }

    func setBiometrics(_ enabled: Bool) throws -> VaultHeader {
        guard let key = vaultKey, var current = header else { throw VaultStoreError.vaultLocked }

        if enabled {
            do {
                let applied = try VaultKeychain.save(key, userPresence: true)
                guard applied == "userPresence" else {
                    VaultKeychain.delete()
                    throw VaultStoreError.keychain("这台设备无法启用系统验证，请确认已设置锁屏密码。")
                }
            } catch let error as KeychainError {
                VaultKeychain.delete()
                throw VaultStoreError.keychain(error.errorDescription ?? "无法写入钥匙串。")
            }
            current.biometric = true
        } else {
            VaultKeychain.delete()
            current.biometric = false
        }

        header = current
        try writeHeader()
        return current
    }

    private func disableBiometrics() throws {
        VaultKeychain.delete()
        guard let diskHeader = readHeader() else { return }
        var current = diskHeader
        current.biometric = false
        header = current
        try writeHeader()
    }

    func exportContent() throws -> VaultContent {
        guard let key = vaultKey, let current = header else { throw VaultStoreError.vaultLocked }
        return try decryptPayload(current.payload, key: key)
    }

    func replaceContent(_ content: VaultContent) throws -> (VaultHeader, VaultContent) {
        let updatedHeader = try save(content: content)
        return (updatedHeader, content)
    }

    // MARK: 媒体文件（用同一把库密钥加密）

    func storeMediaFile(_ data: Data) throws -> String {
        guard let key = vaultKey else { throw VaultStoreError.vaultLocked }
        try ensureMediaDirectory()
        let name = UUID().uuidString + ".bin"
        let box = try AESGCM.encrypt(data, key: key)
        let blob = box.nonce + box.cipher + box.tag
        let url = mediaDirectoryURL.appendingPathComponent(name)
        try blob.write(to: url, options: [.atomic, .completeFileProtection])
        return name
    }

    func loadMediaFile(_ name: String) throws -> Data {
        guard let key = vaultKey else { throw VaultStoreError.vaultLocked }
        let url = mediaDirectoryURL.appendingPathComponent(name)
        let blob = try Data(contentsOf: url)
        guard blob.count > 12 + 16 else { throw VaultStoreError.mediaUnreadable }
        let nonce = blob.prefix(12)
        let tag = blob.suffix(16)
        let cipher = blob.dropFirst(12).dropLast(16)
        return try AESGCM.decrypt(cipher: cipher, nonce: nonce, tag: tag, key: key)
    }

    func deleteMediaFile(_ name: String) {
        let url = mediaDirectoryURL.appendingPathComponent(name)
        try? fileManager.removeItem(at: url)
    }

    // MARK: 数据管理

    func deleteEverything() {
        vaultKey = nil
        header = nil
        VaultKeychain.delete()
        try? fileManager.removeItem(at: directoryURL)
    }
}

enum KDFProfile {
    static let password = 120_000
    static let gesture = 40_000
    static let backup = 120_000
}
