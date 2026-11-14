import Foundation
import CryptoKit

// MARK: - 错误

enum CryptoError: LocalizedError {
    case pbkdf2Failed
    case invalidKeyLength
    case encryptFailed
    case decryptFailed
    case invalidPayload
    case invalidSalt

    var errorDescription: String? {
        switch self {
        case .pbkdf2Failed: return "密钥派生出错。"
        case .invalidKeyLength: return "密钥长度无效。"
        case .encryptFailed: return "加密失败。"
        case .decryptFailed: return "解密失败：密码不正确，或文件已损坏。"
        case .invalidPayload: return "数据格式无法识别。"
        case .invalidSalt: return "随机数生成失败。"
        }
    }
}

// MARK: - 底层工具

enum CryptoUtils {

    static func randomBytes(_ count: Int) throws -> Data {
        guard count > 0 else { throw CryptoError.invalidSalt }
        var generator = SystemRandomNumberGenerator()
        var result = Data()
        result.reserveCapacity(count)
        while result.count < count {
            result.append(UInt8.random(in: 0...255, using: &generator))
        }
        return result
    }

    /// PBKDF2-HMAC-SHA256（纯 Swift 实现，不依赖 CommonCrypto）。
    /// - 时间复杂度 O(轮数)；iPhone 上 21 万轮约 0.2–0.5 秒。
    static func pbkdf2SHA256(password: String, salt: Data, iterations: Int, keyLength: Int = 32) throws -> Data {
        guard iterations > 0, keyLength > 0 else { throw CryptoError.pbkdf2Failed }
        guard let passwordData = password.data(using: .utf8) else { throw CryptoError.pbkdf2Failed }

        let passwordKey = SymmetricKey(data: passwordData)
        let hashLength = 32
        let blocks = Int(ceil(Double(keyLength) / Double(hashLength)))
        var derived = Data()

        for blockIndex in 1...blocks {
            var bigEndian = UInt32(blockIndex).bigEndian
            var initial = salt
            withUnsafeBytes(of: &bigEndian) { initial.append(contentsOf: $0) }

            var u = Data(HMAC<SHA256>.authenticationCode(for: initial, using: passwordKey))
            var t = u

            if iterations > 1 {
                for _ in 2...iterations {
                    u = Data(HMAC<SHA256>.authenticationCode(for: u, using: passwordKey))
                    for i in 0..<t.count {
                        t[i] ^= u[i]
                    }
                }
            }
            derived.append(t)
        }

        guard derived.count >= keyLength else { throw CryptoError.pbkdf2Failed }
        return derived.prefix(keyLength)
    }

    static func sha256(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }

    static func constantTimeEquals(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for i in 0..<lhs.count {
            difference |= lhs[i] ^ rhs[i]
        }
        return difference == 0
    }
}

// MARK: - AES-256-GCM

struct AESSealedBox {
    var nonce: Data
    var cipher: Data
    var tag: Data

    var headerPayload: VaultHeader.EncryptedPayload {
        VaultHeader.EncryptedPayload(algorithm: "AES-256-GCM", nonce: nonce, cipher: cipher, tag: tag)
    }
}

enum AESGCM {
    static func encrypt(_ plaintext: Data, key: Data) throws -> AESSealedBox {
        guard key.count == 32 else { throw CryptoError.invalidKeyLength }
        do {
            let box = try AES.GCM.seal(plaintext, using: SymmetricKey(data: key))
            return AESSealedBox(nonce: Data(box.nonce), cipher: box.ciphertext, tag: box.tag)
        } catch {
            throw CryptoError.encryptFailed
        }
    }

    static func decrypt(cipher: Data, nonce: Data, tag: Data, key: Data) throws -> Data {
        guard key.count == 32 else { throw CryptoError.invalidKeyLength }
        do {
            let box = try AES.GCM.SealedBox(
                nonce: try AES.GCM.Nonce(data: nonce),
                ciphertext: cipher,
                tag: tag
            )
            return try AES.GCM.open(box, using: SymmetricKey(data: key))
        } catch {
            throw CryptoError.decryptFailed
        }
    }
}

// MARK: - JSON 编解码

enum VaultCodec {
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        try makeEncoder().encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try makeDecoder().decode(type, from: data)
    }
}

// MARK: - 密码强度（只用于界面提示，不参与加密）

enum PasswordStrength: Int {
    case weak = 0
    case fair = 1
    case good = 2
    case strong = 3

    var title: String {
        switch self {
        case .weak: return "偏弱"
        case .fair: return "一般"
        case .good: return "不错"
        case .strong: return "很强"
        }
    }

    static func evaluate(_ password: String) -> PasswordStrength {
        if password.isEmpty { return .weak }
        var classes = 0
        var hasLower = false
        var hasUpper = false
        var hasDigit = false
        var hasSymbol = false
        for scalar in password.unicodeScalars {
            let v = scalar.value
            if v >= 97 && v <= 122 { hasLower = true }
            else if v >= 65 && v <= 90 { hasUpper = true }
            else if v >= 48 && v <= 57 { hasDigit = true }
            else { hasSymbol = true }
        }
        if hasLower { classes += 1 }
        if hasUpper { classes += 1 }
        if hasDigit { classes += 1 }
        if hasSymbol { classes += 1 }

        let length = password.count
        if length < 8 { return .weak }
        if length >= 16 && classes >= 3 { return .strong }
        if length >= 12 && classes >= 2 { return .good }
        if length >= 10 || (length >= 8 && classes >= 3) { return .fair }
        return .weak
    }
}
