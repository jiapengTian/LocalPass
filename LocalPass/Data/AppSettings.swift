import Foundation
import Combine

// MARK: - 偏好设置

final class AppSettings: ObservableObject {

    enum AutoLockDelay: Int, CaseIterable, Identifiable {
        case immediately = 0
        case thirtySeconds = 30
        case oneMinute = 60
        case fiveMinutes = 300
        case never = -1

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .immediately: return "立即"
            case .thirtySeconds: return "30 秒"
            case .oneMinute: return "1 分钟"
            case .fiveMinutes: return "5 分钟"
            case .never: return "从不（不推荐）"
            }
        }
    }

    private enum Keys {
        static let autoLockDelay = "settings.autoLockDelay"
        static let clearClipboard = "settings.clearClipboardEnabled"
        static let clipboardSeconds = "settings.clipboardSeconds"
        static let biometricEnabled = "settings.biometricEnabled"
    }

    @Published var autoLockDelay: Int {
        didSet { UserDefaults.standard.set(autoLockDelay, forKey: Keys.autoLockDelay) }
    }

    @Published var clearClipboardEnabled: Bool {
        didSet { UserDefaults.standard.set(clearClipboardEnabled, forKey: Keys.clearClipboard) }
    }

    @Published var clipboardClearSeconds: Int {
        didSet { UserDefaults.standard.set(clipboardClearSeconds, forKey: Keys.clipboardSeconds) }
    }

    /// 是否在「设置」里勾选了系统验证解锁（真正的开关状态以文件头的 biometric 为准）。
    @Published var biometricEnabled: Bool {
        didSet { UserDefaults.standard.set(biometricEnabled, forKey: Keys.biometricEnabled) }
    }

    init() {
        let defaults = UserDefaults.standard
        let storedDelay = defaults.object(forKey: Keys.autoLockDelay) as? Int
        autoLockDelay = storedDelay ?? AppSettings.AutoLockDelay.oneMinute.rawValue

        if defaults.object(forKey: Keys.clearClipboard) == nil {
            clearClipboardEnabled = true
        } else {
            clearClipboardEnabled = defaults.bool(forKey: Keys.clearClipboard)
        }

        let storedSeconds = defaults.object(forKey: Keys.clipboardSeconds) as? Int
        clipboardClearSeconds = storedSeconds ?? 30
        biometricEnabled = defaults.bool(forKey: Keys.biometricEnabled)
    }

    var autoLockDelayValue: AutoLockDelay {
        AutoLockDelay(rawValue: autoLockDelay) ?? .oneMinute
    }

    /// 0 表示「切到后台就立刻锁定」。
    var lockAfterSeconds: Int? {
        let delay = autoLockDelayValue
        return delay == .never ? nil : delay.rawValue
    }

    static func resetAll() {
        let defaults = UserDefaults.standard
        [Keys.autoLockDelay, Keys.clearClipboard, Keys.clipboardSeconds, Keys.biometricEnabled]
            .forEach { defaults.removeObject(forKey: $0) }
    }
}
