import SwiftUI
import UIKit

// MARK: - 颜色工具

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8 else { return nil }
        guard let v = UInt64(s, radix: 16) else { return nil }
        let r, g, b, a: Double
        if s.count == 6 {
            r = Double((v >> 16) & 0xFF) / 255
            g = Double((v >> 8) & 0xFF) / 255
            b = Double(v & 0xFF) / 255
            a = 1
        } else {
            r = Double((v >> 24) & 0xFF) / 255
            g = Double((v >> 16) & 0xFF) / 255
            b = Double((v >> 8) & 0xFF) / 255
            a = Double(v & 0xFF) / 255
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - 设计系统

enum Theme {
    // 底色
    static let ink0 = Color(hex: "#070911")!
    static let ink1 = Color(hex: "#0B0E1A")!
    static let ink2 = Color(hex: "#101426")!

    // 玻璃
    static let surface = Color.white.opacity(0.055)
    static let surface2 = Color.white.opacity(0.085)
    static let surface3 = Color.white.opacity(0.12)
    static let stroke = Color.white.opacity(0.09)
    static let strokeStrong = Color.white.opacity(0.16)

    // 文字
    static let text = Color(hex: "#F3F5FF")!
    static let text2 = Color(hex: "#BABFC8")!.opacity(0.68)
    static let text3 = Color(hex: "#BABFC8")!.opacity(0.42)

    // 品牌
    static let violet = Color(hex: "#7C6CFF")!
    static let violet2 = Color(hex: "#9B8CFF")!
    static let cyan = Color(hex: "#3FD9F5")!
    static let mint = Color(hex: "#3EE6A8")!
    static let pink = Color(hex: "#FF7AB6")!
    static let amber = Color(hex: "#FFC061")!
    static let danger = Color(hex: "#FF6B7A")!
    static let amberText = Color(hex: "#FFD79A")!

    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#6A5BFF")!, Color(hex: "#A26BFF")!, Color(hex: "#FF7AB6")!],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var cardGradient: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.085), Color.white.opacity(0.028)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var titleGradient: LinearGradient {
        LinearGradient(
            colors: [Color.white, Color.white.opacity(0.66)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func aurora(_ size: CGSize) -> some View {
        ZStack {
            LinearGradient(colors: [ink1, ink0], startPoint: .top, endPoint: .bottom)
            RadialGradient(
                colors: [Theme.violet.opacity(0.42), .clear],
                center: UnitPoint(x: 0.15, y: 0.05),
                startRadius: 8,
                endRadius: max(size.width, size.height) * 0.75
            )
            RadialGradient(
                colors: [Theme.cyan.opacity(0.22), .clear],
                center: UnitPoint(x: 0.92, y: 0.12),
                startRadius: 4,
                endRadius: max(size.width, size.height) * 0.55
            )
            RadialGradient(
                colors: [Theme.pink.opacity(0.18), .clear],
                center: UnitPoint(x: 0.35, y: 1.02),
                startRadius: 4,
                endRadius: max(size.width, size.height) * 0.65
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - 玻璃卡片

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 18
    var padding: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.cardGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
    }
}

struct AuroraBackground: View {
    var body: some View {
        GeometryReader { proxy in
            Theme.aurora(proxy.size)
        }
    }
}

// MARK: - 按钮

struct PrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.brandGradient)
                    .opacity(enabled ? (configuration.isPressed ? 0.82 : 1) : 0.4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Theme.violet.opacity(enabled ? 0.5 : 0), radius: 18, x: 0, y: 10)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Theme.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct SolidWhiteButtonStyle: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color(hex: "#3D2FB8")!)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(enabled ? 1 : 0.5))
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct IconButtonStyle: ButtonStyle {
    var accent: Bool = false
    var size: CGFloat = 40

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.45, weight: .medium))
            .foregroundStyle(accent ? Color.white : Theme.text)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.36, style: .continuous)
                    .fill(accent ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Theme.surface))
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.36, style: .continuous)
                    .strokeBorder(accent ? Color.clear : Theme.stroke, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - 胶囊 / 标签

struct PillStyle: ButtonStyle {
    var selected: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13.5, weight: selected ? .semibold : .medium))
            .foregroundStyle(selected ? Color.white : Theme.text2)
            .padding(.horizontal, 15)
            .frame(height: 34)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Theme.surface))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(selected ? Color.clear : Theme.stroke, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct DashedPillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13.5, weight: .medium))
            .foregroundStyle(Theme.violet2)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(
                Capsule(style: .continuous)
                    .strokeBorder(Theme.violet.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - 图标色块

struct CategoryBadge: View {
    var category: VaultCategory
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: category.symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(category.color)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .fill(category.color.opacity(0.16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .strokeBorder(category.color.opacity(0.24), lineWidth: 1)
            )
    }
}

struct StatPill: View {
    var symbol: String
    var value: String
    var label: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text(label)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.text3)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
        )
    }
}

// MARK: - 头像（随网址变化）

struct BrandAvatarView: View {
    var item: VaultItem
    var size: CGFloat
    var brand: BrandInfo

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [brand.color.opacity(0.26), brand.color.opacity(0.07)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: brand.symbol)
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(brand.color)

            // 手动上传的图标
            if let data = item.customIcon, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.16)
            } else if let url = brand.faviconURL {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(size * 0.18)
                    } else {
                        Color.clear
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .strokeBorder(brand.color.opacity(0.22), lineWidth: 1)
        )
    }
}

// MARK: - 提示条

struct ToastView: View {
    var message: ToastMessage
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: message.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.violet2)
            Text(message.text)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.text2)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: "#161A2C")!.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.strokeStrong, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 12)
        .padding(.horizontal, 18)
    }
}
