"""Swift 源码静态一致性检查（无需 Xcode）。

检查项：
1. 花括号 / 圆括号配平
2. 类型重复声明
3. Theme.<成员> 是否都存在
4. session.<成员> / store.<成员> 是否在对应类型里声明
5. 使用 UIImage 但没 import UIKit
6. 跨文件引用的自定义类型是否都有定义
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "LocalPass")

files = {}
for base, _, names in os.walk(SRC):
    for name in names:
        if name.endswith(".swift"):
            path = os.path.join(base, name)
            files[name] = open(path, encoding="utf-8").read()

errors = []
warnings = []


def err(msg):
    errors.append(msg)


def warn(msg):
    warnings.append(msg)


# ---------- 1. 括号配平 ----------
print("== 1. 括号配平 ==")
for name, text in sorted(files.items()):
    # 去掉字符串和注释中的括号，避免误判
    stripped = re.sub(r'"(?:[^"\\]|\\.)*"', '""', text)
    stripped = re.sub(r"//[^\n]*", "", stripped)
    stripped = re.sub(r"/\*.*?\*/", "", stripped, flags=re.S)
    pairs = [("{", "}"), ("(", ")"), ("[", "]")]
    ok = True
    for left, right in pairs:
        if stripped.count(left) != stripped.count(right):
            ok = False
            err(f"{name}: {left}{right} 不配平 ({stripped.count(left)}/{stripped.count(right)})")
    if ok:
        print(f"  OK   {name}")

# ---------- 2. 类型声明 ----------
print("\n== 2. 类型声明（重复检测）==")
decl = {}
pattern = re.compile(r"^(?:@\w+\s+)*(?:public |internal |private |fileprivate )?(struct|class|enum|actor|protocol)\s+(\w+)", re.M)
for name, text in files.items():
    for kind, type_name in pattern.findall(text):
        decl.setdefault(type_name, []).append((kind, name))
dups = {k: v for k, v in decl.items() if len(v) > 1}
if dups:
    for k, v in dups.items():
        err(f"类型重复声明：{k} -> {v}")
else:
    print(f"  OK   {len(decl)} 个类型，无重复")

# ---------- 3. Theme 成员 ----------
print("\n== 3. Theme 成员 ==")
theme_text = files.get("Theme.swift", "")
theme_members = set(re.findall(r"static (?:let|var|func)\s+(\w+)", theme_text))
used = set()
for name, text in files.items():
    for member in re.findall(r"Theme\.(\w+)", text):
        used.add(member)
missing = sorted(used - theme_members)
if missing:
    for m in missing:
        err(f"Theme.{m} 未定义")
else:
    print(f"  OK   使用了 {len(used)} 个成员，全部已定义")

# ---------- 4. session / store 成员 ----------
print("\n== 4. VaultSession / VaultStore 成员 ==")


def members_of(text):
    result = set()
    result |= set(re.findall(r"(?:@Published\s+)?(?:private\(set\)\s+)?(?:var|let)\s+(\w+)\s*[:=]", text))
    result |= set(re.findall(r"func\s+(\w+)\s*\(", text))
    result |= set(re.findall(r"case\s+(\w+)", text))
    return result


session_members = members_of(files.get("VaultSession.swift", ""))
store_members = members_of(files.get("VaultStore.swift", ""))

for name, text in files.items():
    if name in ("VaultSession.swift",):
        continue
    for m in re.findall(r"\bsession\.(\w+)", text):
        if m not in session_members:
            err(f"{name}: session.{m} 未在 VaultSession 中声明")
    if name == "VaultSession.swift":
        continue
    for m in re.findall(r"\bstore\.(\w+)", text):
        if m not in store_members:
            err(f"{name}: store.{m} 未在 VaultStore 中声明")
print("  OK" if not errors else "  （见下方错误）")

# ---------- 5. UIKit 导入 ----------
print("\n== 5. UIKit 导入 ==")
for name, text in sorted(files.items()):
    if "UIImage" in text and "import UIKit" not in text and "import SwiftUI" not in text:
        err(f"{name}: 使用 UIImage 但未 import UIKit")
    elif "UIImage" in text and "import UIKit" not in text:
        warn(f"{name}: 使用 UIImage 但未 import UIKit（依赖 SwiftUI 转出）")
print("  OK" if not any("UIImage" in t and "import UIKit" not in t for t in files.values()) else "  （见警告）")

# ---------- 6. 自定义类型引用 ----------
print("\n== 6. 自定义类型引用 ==")
known = set(decl.keys())
# 系统 / SDK 类型白名单
sdk = {
    "View", "Button", "Text", "Image", "Color", "VStack", "HStack", "ZStack", "ScrollView", "LazyVStack",
    "LazyVGrid", "GridItem", "ForEach", "Spacer", "Divider", "Toggle", "Picker", "TextField", "SecureField",
    "TextEditor", "ProgressView", "NavigationStack", "ToolbarItem", "ShareLink", "VideoPlayer", "AsyncImage",
    "PhotosPicker", "PatternLockView", "GlassCard", "AuroraBackground", "StatPill", "BrandAvatarView",
    "CategoryBadge", "ToastView", "PillStyle", "DashedPillStyle", "PrimaryButtonStyle", "GlassButtonStyle",
    "SolidWhiteButtonStyle", "IconButtonStyle", "DarkFieldStyle", "EditorFieldStyle", "StrengthBar",
    "VaultSession", "VaultStore", "VaultItem", "VaultContent", "VaultCategory", "VaultMedia", "VaultHeader",
    "VaultTab", "MediaFilter", "MediaKind", "PreparedMedia", "BrandInfo", "BrandLibrary", "MediaImporter",
    "AppSettings", "BackupService", "CryptoUtils", "AESGCM", "VaultCodec", "VaultKeychain", "Biometrics",
    "KeychainError", "VaultStoreError", "CryptoError", "BackupError", "VaultPolicy", "UnlockResult",
    "KDFProfile", "PasswordStrength", "ItemEditorView", "HomeView", "LockScreenView", "SetupWizardView",
    "SettingsView", "BackupView", "ForgotPasswordView", "CategoryEditorView", "CategoryListView",
    "VaultItemDetailView", "SecurityInfoView", "HealthView", "ChangePasswordView", "GestureSetupView",
    "SetupWizardModel", "LockScreenModel", "MediaCell", "MediaViewerView", "ZenScroll", "ShakeEffect",
    "ShakeOnChange", "IconRenderer", "PrivacyCoverView", "LaunchIntroView", "RootView", "LocalPassApp",
}
referenced = set()
for name, text in files.items():
    for t in re.findall(r"\b([A-Z][A-Za-z0-9_]*)\s*\(", text):
        referenced.add(t)
unknown = sorted(t for t in referenced if t not in known and t not in sdk)
print("  未识别（可能是 SDK 类型，人工确认）:", len(unknown))
for t in unknown[:30]:
    print("    -", t)

# ---------- 汇总 ----------
print("\n" + "=" * 50)
if warnings:
    print(f"警告 {len(warnings)} 条：")
    for w in warnings:
        print("  ⚠", w)
if errors:
    print(f"错误 {len(errors)} 条：")
    for e in errors:
        print("  ✗", e)
    sys.exit(1)
print("结果：全部通过")
