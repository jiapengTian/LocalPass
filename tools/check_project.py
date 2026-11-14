#!/usr/bin/env python3
"""对 LocalPass 工程做静态一致性检查（无需 Xcode）。"""
import json
import os
import plistlib
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(ROOT, "LocalPass")
PROJ = os.path.join(ROOT, "LocalPass.xcodeproj", "project.pbxproj")

errors = []
warnings = []


def check(cond, message):
    if cond:
        print(f"  OK   {message}")
    else:
        errors.append(message)
        print(f"  FAIL {message}")


print("== 1. pbxproj 结构 ==")
text = open(PROJ, encoding="utf-8").read()
check(text.startswith("// !$*UTF8*$!"), "文件头标记")
check(text.rstrip().endswith("}"), "括号闭合到文件末尾")

open_braces = text.count("{")
close_braces = text.count("}")
check(open_braces == close_braces, f"花括号数量一致 ({open_braces}/{close_braces})")
open_paren = text.count("(")
close_paren = text.count(")")
check(open_paren == close_paren, f"圆括号数量一致 ({open_paren}/{close_paren})")

# 所有被引用的对象 ID 都必须有定义
defined = set(re.findall(r"^\t\t([0-9A-F]{24}) ", text, re.M))
referenced = set(re.findall(r"([0-9A-F]{24})", text))
undefined = sorted(referenced - defined)
check(not undefined, f"所有引用的对象 ID 均已定义（未定义 {len(undefined)} 个）")
if undefined:
    print("       未定义:", undefined)

# 每个 buildFile 的 fileRef 必须存在
build_files = re.findall(
    r"([0-9A-F]{24}) /\* .*? \*/ = \{isa = PBXBuildFile; fileRef = ([0-9A-F]{24})",
    text,
)
check(len(build_files) > 0, f"解析到 {len(build_files)} 个 PBXBuildFile")
for bf, ref in build_files:
    check(ref in defined, f"buildFile {bf} 的 fileRef {ref} 存在")

print("\n== 2. 源码文件登记 ==")
sources_phase = re.search(r"/\* Begin PBXSourcesBuildPhase section \*/(.*?)/\* End", text, re.S).group(1)
compiled = set(re.findall(r"/\* (\S+\.swift) in Sources \*/", sources_phase))
on_disk = set()
for base, _, files in os.walk(APP):
    for f in files:
        if f.endswith(".swift"):
            on_disk.add(f)
check(compiled == on_disk, f"Sources 阶段与磁盘 .swift 文件一致（工程 {len(compiled)} / 磁盘 {len(on_disk)}）")
missing = sorted(on_disk - compiled)
extra = sorted(compiled - on_disk)
if missing:
    print("       未编译:", missing)
if extra:
    print("       工程里有但磁盘没有:", extra)

print("\n== 3. 资源与 plist ==")
check("Assets.xcassets in Resources" in text, "Assets.xcassets 已加入 Resources")
check(os.path.exists(os.path.join(APP, "Assets.xcassets", "AppIcon.appiconset", "AppIcon-1024.png")), "1024 图标存在")
check(
    os.path.exists(os.path.join(APP, "Assets.xcassets", "LaunchBackground.colorset", "Contents.json")),
    "启动背景色存在",
)

info_path = os.path.join(APP, "Info.plist")
with open(info_path, "rb") as fh:
    try:
        info = plistlib.load(fh)
        check(True, "Info.plist 是合法 plist")
    except Exception as exc:  # noqa: BLE001
        info = {}
        check(False, f"Info.plist 解析失败: {exc}")
check("NSFaceIDUsageDescription" in info, "包含 Face ID 权限说明")
check(info.get("CFBundleDisplayName") == "私钥库", "显示名称 = 私钥库")
check("$(PRODUCT_BUNDLE_IDENTIFIER)" == info.get("CFBundleIdentifier"), "Bundle ID 使用构建变量")
check("UILaunchScreen" in info, "包含 UILaunchScreen")
check("IPHONEOS_DEPLOYMENT_TARGET = 16.0" in text, "部署目标 iOS 16.0")
check("SWIFT_VERSION = 5.0" in text, "Swift 语言版本 5.0")

print("\n== 4. 资源目录 JSON ==")
for base, _, files in os.walk(os.path.join(APP, "Assets.xcassets")):
    for f in files:
        if f.endswith(".json"):
            path = os.path.join(base, f)
            try:
                json.load(open(path, encoding="utf-8"))
                check(True, os.path.relpath(path, APP))
            except Exception as exc:  # noqa: BLE001
                check(False, f"{path}: {exc}")

print("\n== 5. 关键类型定义 ==")
swift_text = ""
for base, _, files in os.walk(APP):
    for f in files:
        if f.endswith(".swift"):
            swift_text += open(os.path.join(base, f), encoding="utf-8").read() + "\n"

for name in [
    "@main",
    "struct LocalPassApp",
    "struct RootView",
    "final class VaultSession",
    "actor VaultStore",
    "struct VaultHeader",
    "struct VaultItem",
    "struct VaultContent",
    "enum CryptoUtils",
    "enum AESGCM",
    "struct PatternLockView",
    "struct LockScreenView",
    "struct SetupWizardView",
    "struct HomeView",
    "struct VaultItemDetailView",
    "struct ItemEditorView",
    "struct SettingsView",
    "struct CategoryEditorView",
    "struct BrandAvatarView",
    "enum BrandLibrary",
    "enum MediaImporter",
    "struct VaultMedia",
    "struct VaultCategory",
    "struct BackupView",
    "struct ToastView",
    "struct PrivacyCoverView",
    "struct LaunchIntroView",
    "struct ForgotPasswordView",
    "enum BackupService",
    "final class AppSettings",
]:
    check(name in swift_text, f"定义 {name}")

print("\n== 6. 存档路径与权限 ==")
check("applicationSupportDirectory" in swift_text, "使用 Application Support 目录")
check("completeFileProtection" in swift_text, "文件完整保护")
check("kSecAttrAccessibleWhenUnlockedThisDeviceOnly" in swift_text, "钥匙串仅本机可用")
check("userPresence" in swift_text, "系统验证访问控制")
check("AES.GCM.seal" in swift_text and "AES.GCM.open" in swift_text, "AES-GCM 加解密")
check("pbkdf2SHA256" in swift_text, "PBKDF2 派生")

print("\n== 7. 编码体检（防止中文被写坏）==")
enc_errors = 0
for base, _, files in os.walk(APP):
    for f in files:
        if not f.endswith(".swift"):
            continue
        path = os.path.join(base, f)
        raw = open(path, "rb").read()
        if raw.startswith(b"\xef\xbb\xbf"):
            enc_errors += 1
            check(False, f"{f} 含 UTF-8 BOM")
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError as exc:
            enc_errors += 1
            check(False, f"{f} 不是合法 UTF-8: {exc}")
            continue
        if "\ufffd" in text:
            enc_errors += 1
            check(False, f"{f} 含替换字符 U+FFFD")
        # 常见 GBK 误编码痕迹
        for bad in ["閿", "锛", "銆", "璇", "鏂", "锟"]:
            if bad in text:
                enc_errors += 1
                check(False, f"{f} 疑似 GBK 乱码：{bad}")
                break
if enc_errors == 0:
    check(True, "全部 Swift 文件为干净 UTF-8，无 BOM / 无乱码")

print("\n== 8. 未使用的明显隐患 ==")
# 检查常见的 iOS 17+ API 是否做了可用性判断
for api in ["scrollClipDisabled(", "ContentUnavailableView", ".containerRelativeFrame"]:
    if api in swift_text:
        idx = swift_text.find(api)
        window = swift_text[max(0, idx - 400):idx]
        guarded = "#available(iOS 17" in window
        check(guarded, f"{api} 使用了可用性判断")
    else:
        print(f"  --   {api} 未使用")

print("\n" + "=" * 46)
if errors:
    print(f"结果：{len(errors)} 个问题")
    for err in errors:
        print(" -", err)
    sys.exit(1)
print("结果：全部通过")
