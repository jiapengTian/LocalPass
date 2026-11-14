import Foundation

// MARK: - 加密备份

enum BackupError: LocalizedError {
    case notABackup
    case wrongPasswordOrDamaged

    var errorDescription: String? {
        switch self {
        case .notABackup: return "这不是一个有效的私钥库备份文件。"
        case .wrongPasswordOrDamaged: return "备份密码不正确，或文件已损坏。"
        }
    }

    static func describe(_ error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}

struct BackupEnvelope: Codable {
    var format: String
    var version: Int
    var app: String
    var createdAt: Date
    var kdf: String
    var iterations: Int
    var salt: Data
    var nonce: Data
    var cipher: Data
    var tag: Data
}

enum BackupService {

    static let fileExtension = "lpbk"

    static func makeBackupFileData(content: VaultContent, password: String) throws -> Data {
        try VaultPolicy.validatePassword(password)
        let salt = try CryptoUtils.randomBytes(16)
        let key = try CryptoUtils.pbkdf2SHA256(
            password: password,
            salt: salt,
            iterations: KDFProfile.backup,
            keyLength: 32
        )
        let box = try AESGCM.encrypt(try VaultCodec.encode(content), key: key)
        let envelope = BackupEnvelope(
            format: "LocalPass-Backup",
            version: 1,
            app: "LocalPass",
            createdAt: Date(),
            kdf: "PBKDF2-HMAC-SHA256",
            iterations: KDFProfile.backup,
            salt: salt,
            nonce: box.nonce,
            cipher: box.cipher,
            tag: box.tag
        )
        return try VaultCodec.encode(envelope)
    }

    static func restore(data: Data, password: String) throws -> VaultContent {
        guard let envelope = try? VaultCodec.decode(BackupEnvelope.self, from: data),
              envelope.format == "LocalPass-Backup" else {
            throw BackupError.notABackup
        }
        let key = try CryptoUtils.pbkdf2SHA256(
            password: password,
            salt: envelope.salt,
            iterations: envelope.iterations,
            keyLength: 32
        )
        do {
            let plaintext = try AESGCM.decrypt(
                cipher: envelope.cipher,
                nonce: envelope.nonce,
                tag: envelope.tag,
                key: key
            )
            return try VaultCodec.decode(VaultContent.self, from: plaintext)
        } catch {
            throw BackupError.wrongPasswordOrDamaged
        }
    }

    static func suggestedFileName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return "LocalPass-\(formatter.string(from: Date())).\(fileExtension)"
    }
}
