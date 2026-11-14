import SwiftUI

/// 品牌识别结果：图标符号 + 品牌色 + 可选的网站 favicon 地址
struct BrandInfo {
    var symbol: String
    var color: Color
    var faviconURL: URL?
}

enum BrandLibrary {

    /// 域名 → (SF Symbol, 品牌色)
    private static let table: [String: (String, String)] = [
        "taobao.com": ("bag", "#FF5000"),
        "tmall.com": ("bag", "#FF0036"),
        "jd.com": ("bag", "#E1251B"),
        "pinduoduo.com": ("bag", "#E02E24"),
        "1688.com": ("bag", "#FF6A00"),
        "xiaohongshu.com": ("heart", "#FF2442"),
        "douyin.com": ("waveform", "#050505"),
        "kuaishou.com": ("waveform", "#FF4906"),
        "bilibili.com": ("play.rectangle", "#FB7299"),
        "zhihu.com": ("bubble.left", "#0084FF"),
        "weibo.com": ("globe", "#E6162D"),
        "douban.com": ("book", "#007722"),
        "qq.com": ("bubble.left.and.bubble.right", "#12B7F5"),
        "weixin.qq.com": ("bubble.left.and.bubble.right", "#07C160"),
        "wechat.com": ("bubble.left.and.bubble.right", "#07C160"),
        "alipay.com": ("wallet.pass", "#1677FF"),
        "aliyun.com": ("cloud", "#FF6A00"),
        "aliyuncs.com": ("cloud", "#FF6A00"),
        "tencent.com": ("bubble.left.and.bubble.right", "#12B7F5"),
        "tencentcloud.com": ("cloud", "#006EFF"),
        "huaweicloud.com": ("cloud", "#CF0A2C"),
        "icloud.com": ("cloud", "#3693F3"),
        "apple.com": ("apple.logo", "#E8E8EE"),
        "microsoft.com": ("square.grid.2x2", "#00A4EF"),
        "live.com": ("envelope", "#0078D4"),
        "outlook.com": ("envelope", "#0078D4"),
        "office.com": ("square.grid.2x2", "#D83B01"),
        "google.com": ("globe", "#4285F4"),
        "gmail.com": ("envelope", "#EA4335"),
        "youtube.com": ("play.rectangle", "#FF0000"),
        "github.com": ("chevron.left.forwardslash.chevron.right", "#8B95A8"),
        "gitlab.com": ("chevron.left.forwardslash.chevron.right", "#FC6D26"),
        "gitee.com": ("chevron.left.forwardslash.chevron.right", "#C71D23"),
        "openai.com": ("sparkles", "#10A37F"),
        "chatgpt.com": ("sparkles", "#10A37F"),
        "claude.ai": ("sparkles", "#D97757"),
        "facebook.com": ("globe", "#1877F2"),
        "instagram.com": ("camera", "#E4405F"),
        "x.com": ("globe", "#E8E8EE"),
        "twitter.com": ("globe", "#1DA1F2"),
        "netflix.com": ("play.rectangle", "#E50914"),
        "spotify.com": ("waveform", "#1DB954"),
        "steamcommunity.com": ("gamecontroller", "#1B2838"),
        "epicgames.com": ("gamecontroller", "#313131"),
        "163.com": ("envelope", "#C20C0C"),
        "126.com": ("envelope", "#C20C0C"),
        "qqmail.com": ("envelope", "#12B7F5"),
        "proton.me": ("envelope.badge.shield.half.filled", "#6D4AFF"),
        "csdn.net": ("chevron.left.forwardslash.chevron.right", "#FC5531"),
        "juejin.cn": ("chevron.left.forwardslash.chevron.right", "#1E80FF"),
        "baidu.com": ("globe", "#2932E1"),
        "pan.baidu.com": ("cloud", "#06A7FF"),
        "mi.com": ("iphone", "#FF6900"),
        "xiaomi.com": ("iphone", "#FF6900"),
        "huawei.com": ("iphone", "#CF0A2C"),
        "samsung.com": ("iphone", "#1428A0"),
        "126.net": ("envelope", "#C20C0C"),
        "v2ex.com": ("bubble.left", "#5C6B7A"),
        "segmentfault.com": ("chevron.left.forwardslash.chevron.right", "#009A61")
    ]

    /// 标题关键词 → 品牌（没填网址时兜底）
    private static let titleHints: [(String, String, String)] = [
        ("淘宝", "bag", "#FF5000"), ("天猫", "bag", "#FF0036"), ("京东", "bag", "#E1251B"),
        ("拼多多", "bag", "#E02E24"), ("小红书", "heart", "#FF2442"), ("抖音", "waveform", "#050505"),
        ("快手", "waveform", "#FF4906"), ("哔哩哔哩", "play.rectangle", "#FB7299"), ("B站", "play.rectangle", "#FB7299"),
        ("知乎", "bubble.left", "#0084FF"), ("微博", "globe", "#E6162D"), ("豆瓣", "book", "#007722"),
        ("微信", "bubble.left.and.bubble.right", "#07C160"), ("QQ", "bubble.left.and.bubble.right", "#12B7F5"),
        ("支付宝", "wallet.pass", "#1677FF"), ("阿里云", "cloud", "#FF6A00"), ("腾讯云", "cloud", "#006EFF"),
        ("华为", "iphone", "#CF0A2C"), ("小米", "iphone", "#FF6900"), ("GitHub", "chevron.left.forwardslash.chevron.right", "#8B95A8"),
        ("邮箱", "envelope", "#219E9E"), ("路由器", "wifi.router", "#5A6B8C"), ("服务器", "server.rack", "#D98021")
    ]

    static func domain(of url: String) -> String {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let withScheme = trimmed.range(of: "://") == nil ? "https://\(trimmed)" : trimmed
        guard let host = URLComponents(string: withScheme)?.host else { return "" }
        let lower = host.lowercased()
        return lower.hasPrefix("www.") ? String(lower.dropFirst(4)) : lower
    }

    static func info(for item: VaultItem, category: VaultCategory) -> BrandInfo {
        let dom = domain(of: item.url)
        let title = item.title.lowercased()

        if !dom.isEmpty {
            for (key, value) in table {
                if dom == key || dom.hasSuffix("." + key) {
                    return BrandInfo(
                        symbol: value.0,
                        color: Color(hex: value.1) ?? Theme.violet,
                        faviconURL: faviconURL(for: dom, rawURL: item.url)
                    )
                }
            }
        }

        if !title.isEmpty {
            for (hint, symbol, hex) in titleHints where title.contains(hint.lowercased()) {
                return BrandInfo(
                    symbol: symbol,
                    color: Color(hex: hex) ?? Theme.violet,
                    faviconURL: dom.isEmpty ? nil : faviconURL(for: dom, rawURL: item.url)
                )
            }
        }

        // 兜底：分类图标 + 分类色
        return BrandInfo(
            symbol: category.symbol,
            color: category.color,
            faviconURL: dom.isEmpty ? nil : faviconURL(for: dom, rawURL: item.url)
        )
    }

    /// 网站自己的 favicon（不经过第三方服务）
    static func faviconURL(for domain: String, rawURL: String) -> URL? {
        let scheme = rawURL.lowercased().hasPrefix("http://") ? "http" : "https"
        return URL(string: "\(scheme)://\(domain)/favicon.ico")
    }
}
