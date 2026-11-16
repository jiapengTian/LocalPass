# 私钥库 LocalPass
下载后需要自行做软件签证，网上有教程
一个**完全离线**的 iOS 隐私保险箱：账号密码 + 图片视频，加密后只存在本机，不联网、不同步、不上传。

> 形态：原生 SwiftUI App（iOS 16+），AES-256-GCM 全库加密，双保险箱（密码库 / 图片视频库），深色玻璃视觉。
> 附带一个网页验证版（`web/index.html`），用来在 Windows 上快速验证交互与加密逻辑。

---

## 1. 功能

### 密码库

| 功能 | 说明 |
| --- | --- |
| 加密存储 | 整库序列化后 AES-256-GCM 加密，写入沙盒 `Application Support/LocalPass/vault.vlt` |
| 主密码解锁 | PBKDF2-HMAC-SHA256，12 万轮 + 16 字节随机盐派生 256 位密钥 |
| 系统验证解锁 | 库密钥另存一份到本机钥匙串，带 `userPresence` 访问控制（Face ID / Touch ID / 设备密码） |
| 手势解锁 | 九宫格手势，独立盐值，PBKDF2 4 万轮，可与主密码互为备用 |
| 分类 | 内置 6 类，支持自定义新增 / 改名 / 换图标 / 换色 / 删除（长按分类胶囊即可编辑） |
| 标签 | 点选已有标签 + 输入新标签，全局复用 |
| 图标 | 手动上传（随库加密）> 网站 favicon（按网址自动读取）> 内置品牌图标兜底 |
| 搜索 | 名称、账号、网址、备注、标签 |
| 剪贴板 | 一键复制，15–120 秒后自动清空 |
| 忘记密码 | 加密备份重建 / 数据自检 / 清空重置（本地无找回通道） |

### 图片视频库

| 功能 | 说明 |
| --- | --- |
| 导入 | PhotosPicker 多选照片/视频，图片压缩到最长边 1600px |
| 加密 | 原文件 + 缩略图都用同一把库密钥 AES-GCM 加密，存 `Application Support/LocalPass/Media` |
| 浏览 | 三列网格，视频带时长角标，加载缩略图后才解密原图 |
| 查看 | 全屏查看器，图片直接显示，视频用 AVPlayer 播放 |
| 筛选 | 全部 / 照片 / 视频 |
| 删除 | 同时删除记录与两个加密文件 |

### 通用

- 自动锁定：切后台后按 0 秒 / 30 秒 / 1 分钟 / 5 分钟锁定
- 防偷窥：切后台遮罩；密码默认圆点，可点眼睛临时显示
- 加密备份：独立备份密码导出 `.lpbk`（账号记录 + 缩略图；原视频不随备份）
- 数据自检：查看库文件结构（salt 长度、密文长度、迭代次数），用于区分「密码记错」和「文件损坏」

## 2. 安全设计

```
主密码 ──PBKDF2(12万轮, salt)──▶ KEK ──AES-GCM──▶ 包装后的库密钥
                                                      │
随机 256 位库密钥 ───────────────────────────────────┘
        │
        ├──AES-256-GCM──▶ vault.vlt（账号、分类、标签、媒体元数据、缩略图文件名）
        └──AES-256-GCM──▶ Media/*.bin（原图 / 视频）
```

- 文件写入 `.completeFileProtection`，原子替换 + `.bak` 备份
- 钥匙串条目 `ThisDeviceOnly`，不进 iCloud 钥匙串
- 无网络请求（favicon 是唯一可选的对外请求，可在设置里关闭）

**必须知道的取舍**：忘记主密码无法找回。请定期导出加密备份。

## 3. 目录结构（原生）

```
LocalPass/
├── LocalPass.xcodeproj/
├── LocalPass/
│   ├── App/
│   │   ├── LocalPassApp.swift
│   │   ├── RootView.swift            根视图 / 自动锁定 / 防偷窥
│   │   └── VaultSession.swift        界面唯一状态入口（@MainActor）
│   ├── Core/
│   │   ├── VaultModels.swift         VaultItem / VaultMedia / VaultCategory / 文件头
│   │   ├── Crypto.swift              PBKDF2、AES-GCM、编解码、密码强度
│   │   └── Keychain.swift            钥匙串与生物识别能力检测
│   ├── Data/
│   │   ├── VaultStore.swift          actor：落盘、加解密、改密码、媒体文件
│   │   ├── MediaImporter.swift       PhotosPicker → 压缩 / 视频抽帧
│   │   ├── AppSettings.swift         偏好设置
│   │   └── BackupService.swift       加密备份格式
│   ├── UI/
│   │   ├── HomeView.swift            双保险箱首页（头部主卡 / 切换器 / 两个面板 / 媒体查看器）
│   │   ├── LockScreenView.swift      锁屏（密码 / 手势 / Face ID / 抖动 / 忘记密码入口）
│   │   ├── ForgotPasswordView.swift  备份重建 / 自检 / 重置
│   │   ├── SetupWizardView.swift     首次初始化四步
│   │   ├── VaultItemDetailView.swift
│   │   ├── ItemEditorView.swift      分类胶囊 / 标签选择 / 图标上传
│   │   ├── CategoryEditorView.swift  分类编辑与分类总览
│   │   ├── SettingsView.swift        设置 / 改密码 / 手势 / 自检
│   │   ├── BackupView.swift
│   │   └── Components/
│   │       ├── Theme.swift           设计系统（深色玻璃）
│   │       ├── BrandIcons.swift      品牌表 + favicon 地址
│   │       ├── PatternLock.swift     九宫格手势
│   │       └── LaunchIntroView.swift
│   └── Assets.xcassets/
├── web/index.html                    网页验证版（同一套加密逻辑）
├── docs/SETUP-WINDOWS.md             只有 Windows 时怎么装到 iPhone
└── tools/                            静态检查与算法验证脚本
```

## 4. 构建

- 编译必须在 macOS 上（Xcode 不能跑 Windows）
- 云端构建：`.github/workflows/build-ipa.yml`（GitHub Actions macOS）
- 装机：`docs/SETUP-WINDOWS.md`（云端编译 + Sideloadly）
- 部署目标 iOS 16，Swift 5，无第三方依赖

## 5. 验证

| 项目 | 方法 | 结果 |
| --- | --- | --- |
| 工程文件一致性 | `tools/check_project.py` | 通过（23 个 Swift 文件全部登记） |
| Swift 静态一致性 | `tools/check_swift.py`（括号配平 / 类型重复 / Theme 成员 / session 成员 / UIKit 导入） | 通过 |
| 两轮独立静态审查 | 数据层 + 界面层分别人工审查 23 个文件 | 发现并修复 4 处：`BackupService.describe`、元组 key path、同视图多 sheet、密钥清零方式 |
| 加密算法 | `tools/crypto_roundtrip.test.js`（PBKDF2 对照 OpenSSL + RFC 7914） | 16 项通过 |
| 网页版逻辑 | `tools/test_web.js` | 125 项通过 |

> Swift 代码没有在 macOS 上编译过（本机无 Xcode），首次编译若报错，按报错行号修。
