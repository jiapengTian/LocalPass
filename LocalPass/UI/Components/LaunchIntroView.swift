import SwiftUI

/// 启动过渡页：深色玻璃质感。
struct LaunchIntroView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#151A33")!, Color(hex: "#080A14")!],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Theme.violet.opacity(0.5))
                        .frame(width: 140, height: 140)
                        .blur(radius: 38)

                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Theme.brandGradient)
                        .frame(width: 96, height: 96)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                        )

                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text("私钥库")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(Theme.titleGradient)

                Text("只存在本机的密码")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.text3)
            }
        }
        .ignoresSafeArea()
    }
}
