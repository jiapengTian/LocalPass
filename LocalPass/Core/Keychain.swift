import Foundation
import Security
import LocalAuthentication

// MARK: - 钥匙串

enum KeychainError: LocalizedError {
    case addFailed(OSStatus)
    case readFailed(OSStatus)
    case unexpectedResult
    case userCancelled
    case interactionNotAllowed

    var errorDescription: String? {
        switch self {
        case .addFailed(let status):
            return "无法写入钥匙串（错误码 \(status)）。设备需要设置锁屏密码。"
        case .readFailed(let status):
            return "无法读取钥匙串（错误码 \(status)）。"
        case .unexpectedResult:
            return "钥匙串返回了无法识别的数据。"
        case .userCancelled:
            return "已取消验证。"
        case .interactionNotAllowed:
            return "当前无法进行系统验证，请改用主密码解锁。"
        }
    }

    /// 用户主动取消（包括点「取消」或验证失败），属于可恢复状态。
    static func isUserCancellation(_ error: Error) -> Bool {
        if let keychain = error as? KeychainError {
            switch keychain {
            case .userCancelled, .interactionNotAllowed:
                return true
            default:
                return false
            }
        }
        let nsError = error as NSError
        guard nsError.domain == LAError.errorDomain else { return false }
        guard let code = LAError.Code(rawValue: nsError.code) else { return false }
        switch code {
        case .userCancel, .systemCancel, .appCancel, .userFallback,
             .touchIDLockout, .authenticationFailed, .biometryNotAvailable,
             .biometryNotEnrolled, .passcodeNotSet, .biometryLockout,
             .notInteractive, .invalidContext:
            return true
        default:
            return false
        }
    }
}

/// 只在本机钥匙串保存「库密钥」，从不保存到 iCloud 钥匙串。
/// 可选地加上 `userPresence`（Face ID / Touch ID / 设备密码）访问控制。
enum VaultKeychain {

    private static var service: String {
        if let id = Bundle.main.bundleIdentifier, !id.isEmpty {
            return "\(id).vaultkey"
        }
        return "com.localpass.vaultkey"
    }

    private static let account = "vault-key-v1"

    /// - Parameter userPresence: true 时由系统在读取时弹出 Face ID / 设备密码。
    /// - Returns: 实际生效的访问控制（"userPresence" 或 "none"）。
    @discardableResult
    static func save(_ key: Data, userPresence: Bool) throws -> String {
        delete()

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrLabel as String: "LocalPass Vault Key",
            kSecValueData as String: key,
            kSecAttrSynchronizable as String: false,
            kSecUseDataProtectionKeychain as String: true
        ]

        var applied = "none"
        if userPresence,
           let access = SecAccessControlCreateWithFlags(
               nil,
               kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
               .userPresence,
               nil
           ) {
            query[kSecAttrAccessControl as String] = access
            applied = "userPresence"
        } else {
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            throw KeychainError.addFailed(status)
        }
        return applied
    }

    /// 读取库密钥。若条目带 `userPresence`，系统会先要求 Face ID / 设备密码。
    static func load(reason: String) throws -> Data? {
        let context = LAContext()
        context.localizedReason = reason

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseDataProtectionKeychain as String: true,
            kSecUseAuthenticationContext as String: context
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        if status == errSecSuccess {
            guard let data = result as? Data, !data.isEmpty else {
                throw KeychainError.unexpectedResult
            }
            return data
        }
        if status == errSecUserCanceled || status == errSecAuthFailed {
            throw KeychainError.userCancelled
        }
        if status == errSecInteractionNotAllowed {
            throw KeychainError.interactionNotAllowed
        }
        throw KeychainError.readFailed(status)
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - 生物识别 / 设备密码能力检测

/// 注意：LocalAuthentication 必须在主线程调用，因此整体标记为 MainActor。
@MainActor
enum Biometrics {

    struct Status {
        var canUse: Bool
        var kind: String
        var isEnrolled: Bool
        var hasPasscode: Bool

        var unavailableMessage: String {
            if !hasPasscode { return "设备未设置锁屏密码，无法启用系统验证。" }
            if canUse && !isEnrolled { return "尚未录入 \(kind)，请先在系统设置中录入。" }
            return "这台设备暂不支持系统验证，请使用主密码或手势解锁。"
        }
    }

    static func status() -> Status {
        let context = LAContext()
        var policyError: NSError?
        let hasPasscode = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError)

        // 每次调用都用独立的 error 变量，避免上一次的失败状态残留
        var biometricError: NSError?
        let biometryAvailable = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &biometricError
        )
        let enrollmentMissing = (biometricError?.code == LAError.biometryNotEnrolled.rawValue)
            || (biometryAvailable == false && biometricError?.code == LAError.biometryNotAvailable.rawValue)

        var kind = "Face ID / Touch ID"
        // 注意：.opticID 是 iOS 17 才有的枚举值，这里不能用 case 匹配，否则 iOS 16 目标编译失败。
        switch context.biometryType {
        case .faceID: kind = "Face ID"
        case .touchID: kind = "Touch ID"
        default: kind = "生物识别"
        }

        var canUse = false
        if biometryAvailable && !enrollmentMissing {
            canUse = true
        } else if biometryAvailable == false && hasPasscode {
            // 设备有密码但没有可用生物识别：仍可通过设备密码提供 userPresence
            canUse = true
        }

        return Status(
            canUse: canUse,
            kind: kind,
            isEnrolled: biometryAvailable && !enrollmentMissing,
            hasPasscode: hasPasscode
        )
    }
}
