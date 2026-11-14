# 从零装到 iPhone：具体操作步骤

> 全程在 Windows 上操作。编译由 GitHub 的免费 macOS 机器完成，安装由 Sideloadly 完成。
> 需要的账号：GitHub 账号（免费）+ Apple ID（免费）。

---

## 准备清单

| 项目 | 说明 |
| --- | --- |
| 工程包 | `LocalPass-upload.zip`（我给你的那个，58 个文件） |
| GitHub 账号 | https://github.com/join 注册，需邮箱验证 |
| Apple ID | 手机上「设置 → 顶部头像」可看到；免费账号即可 |
| iTunes | 从 https://www.apple.com/itunes/ 下载 Windows 版（Sideloadly 需要它的驱动） |
| Sideloadly | 从 https://sideloadly.io/ 下载 Windows 版 |
| 数据线 | 首次连接要「信任此电脑」 |

---

## 第 1 步：把工程传到 GitHub

### 1.1 解压

把 `LocalPass-upload.zip` 解压到一个空文件夹，例如：

```
D:\LocalPass\
```

解压后应该有：

```
D:\LocalPass\
├── .github\workflows\build-ipa.yml
├── LocalPass\
├── LocalPass.xcodeproj\
├── docs\
├── tools\
└── README.md
```

> `.github` 是隐藏文件夹。在资源管理器「查看 → 显示 → 隐藏的项目」里勾选后能看到。

### 1.2 新建仓库

1. 浏览器打开 https://github.com/new
2. **Repository name** 填 `LocalPass`
3. **Visibility** 选 **Public**（私有仓库用不了免费 macOS 构建额度）
4. 不要勾选 README / .gitignore / license
5. 点 **Create repository**

### 1.3 上传文件（网页方式，不用装 Git）

1. 在新仓库页面点 **uploading an existing file**（或 **Add file → Upload files**）
2. 打开 `D:\LocalPass\`，**全选里面的所有内容**（`Ctrl+A`），拖进浏览器上传框
   - 必须包含 `.github`、`LocalPass`、`LocalPass.xcodeproj` 三个文件夹
3. 等文件列表全部出现（约 58 个），底部点 **Commit changes**

**如果 `.github` 没被拖上去**（最常见的问题）：

1. 仓库页点 **Add file → Create new file**
2. 文件名输入：`.github/workflows/build-ipa.yml`
3. 把本地 `D:\LocalPass\.github\workflows\build-ipa.yml` 的内容整个复制进去
4. 点 **Commit changes**

### 1.4 检查

仓库首页应该能看到 `.github`、`LocalPass`、`LocalPass.xcodeproj`。点进 `.github/workflows/build-ipa.yml` 能打开，说明上传成功。

---

## 第 2 步：让 GitHub 编译出 .ipa

1. 打开你的仓库，点顶部 **Actions**
2. 第一次进来会出现提示，点 **I understand my workflows, go ahead and enable them**
3. 左侧点 **Build unsigned IPA**
4. 右侧点 **Run workflow** → 小窗里 `bundle_id` 留空 → 绿色 **Run workflow**
5. 刷新页面，会出现一条橙色圆点 → 变绿色 ✓（约 3–8 分钟）

### 2.1 下载

1. 点进这次成功的构建
2. 页面滚到底部 **Artifacts** → 点 **LocalPass-ipa** 下载
3. 得到 `LocalPass-ipa.zip`，解压出 **`LocalPass.ipa`**

### 2.2 如果构建失败

点红色的步骤，把最后 20 行日志复制给我。常见原因：

| 现象 | 原因 |
| --- | --- |
| `xcodebuild: error: ... does not contain a project` | `.xcodeproj` 没上传完整 |
| Swift 编译错误（`error: cannot find ...`） | 代码问题，把文件行号发我 |
| 找不到 workflow | `.github/workflows/build-ipa.yml` 缺失或路径不对 |

---

## 第 3 步：用 Sideloadly 安装到 iPhone

1. 装好 iTunes，打开一次，确认能识别手机
2. 装好 Sideloadly，打开
3. 数据线连上 iPhone，手机上点 **信任**，输入锁屏密码
4. Sideloadly 界面：

| 字段 | 填什么 |
| --- | --- |
| **Apple ID** | 你的 Apple ID 邮箱 |
| **IPA** | 点选第 2 步的 `LocalPass.ipa` |
| **Device** | 下拉选你的 iPhone（显示 `iPhone (iOS xx.x)`） |
| **Bundle ID** | 保持默认 `com.localpass.app`；如果提示被占用，改成 `com.你的名字.localpass` |

5. 点 **Start**
6. 第一次会弹窗要 Apple ID 密码（或 App 专用密码），输入后等它签名并安装（1–3 分钟）

### 3.1 手机上还要做两件事

1. **信任开发者**
   设置 → 通用 → VPN与设备管理 → **开发者 App** → 点你的 Apple ID → **信任**
2. **打开开发者模式**（iOS 16 及以上必须）
   设置 → 隐私与安全性 → 滑到底 **开发者模式** → 打开 → 重启手机 → 重启后点 **打开**

完成后桌面上会出现「私钥库」图标。

---

## 第 4 步：第一次使用

1. 打开 App → 设置主密码（至少 8 位）→ 建议填密码提示
2. 选择是否开启 Face ID 解锁
3. 画一个至少 4 个点的手势（可跳过）
4. 点 **创建密码库**
5. 进首页后：密码库点右上 `+` 加账号；图片视频库点右上按钮导入照片视频

**第一件事**：设置 → 数据 → 导出加密备份，存一份到电脑。本地库没有找回通道。

---

## 第 5 步：7 天后续签（免费 Apple ID 的限制）

免费账号签名的 App **7 天后打不开**。数据不会丢，因为 App 沙盒还在。

续签步骤：

1. 打开 Sideloadly，连手机
2. 选**同一个** `LocalPass.ipa`，点 **Start**
3. 完成后 App 恢复可用，**记录还在**

⚠️ 不要先卸载 App 再装 —— 卸载会删掉沙盒里的密码库和媒体文件。要卸载前先导出备份。

---

## 常见问题

| 问题 | 处理 |
| --- | --- |
| Sideloadly 提示 `Unable to connect to device` | 换原装线；打开 iTunes 确认能识别；重启 Apple Mobile Device Service |
| `Provisioning profile doesn't include signing certificate` | Bundle ID 改成唯一的，例如 `com.zhang.localpass` |
| 手机上提示「不受信任的开发者」 | 设置 → 通用 → VPN与设备管理 → 信任 |
| 点开闪退 | 确认开发者模式已开并重启过；再连 Sideloadly 看日志 |
| 打开一片空白 / 界面错位 | 把 Xcode 编译日志或截图发我 |
| App 里打开相机/相册没反应 | 设置 → 私钥库 → 照片 → 允许 |

---

## 关于「只存在本机」

- 编译产物 `.ipa` 会经过 GitHub 传输，但**你的密码数据不在里面**，数据在 App 里第一次运行时才生成
- App 运行时不联网（唯一可选的对外请求是读取网站 favicon，可在设置里关闭）
- 想让数据离开手机，只有「导出加密备份」这一条路
