import Foundation
import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers
import UIKit

/// 把 PhotosPicker 选中的图片 / 视频处理成可加密保存的数据。
enum MediaImporter {

    static let maxThumbSide: CGFloat = 320
    static let maxImageSide: CGFloat = 1600

    /// - Parameter item: PhotosPickerItem
    /// - Returns: 准备好导入的媒体；不支持的格式返回 nil
    static func prepare(from item: PhotosPickerItem) async -> PreparedMedia? {
        let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }

        if isVideo {
            return await prepareVideo(data: data)
        }
        return prepareImage(data: data, suggestedName: item.itemIdentifier ?? "photo")
    }

    // MARK: 图片

    private static func prepareImage(data: Data, suggestedName: String) -> PreparedMedia? {
        guard let image = UIImage(data: data) else { return nil }

        let scale = min(1, maxImageSide / max(image.size.width, image.size.height, 1))
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = draw(image, into: target) ?? image

        let payload = resized.jpegData(compressionQuality: 0.85) ?? data
        let thumb = thumbnail(from: image, maxSide: maxThumbSide)

        return PreparedMedia(
            kind: .image,
            name: suggestedName.hasSuffix(".jpg") ? suggestedName : "照片 \(shortStamp()).jpg",
            mime: "image/jpeg",
            width: Int(resized.size.width),
            height: Int(resized.size.height),
            duration: 0,
            payload: payload,
            thumbnail: thumb,
            byteSize: payload.count
        )
    }

    // MARK: 视频

    private static func prepareVideo(data: Data) async -> PreparedMedia? {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mov")
        do {
            try data.write(to: temp, options: .atomic)
        } catch {
            return nil
        }
        defer { try? FileManager.default.removeItem(at: temp) }

        let asset = AVURLAsset(url: temp)
        let duration = CMTimeGetSeconds(asset.duration)

        var width = 0
        var height = 0
        if let track = asset.tracks(withMediaType: .video).first {
            let size = track.naturalSize.applying(track.preferredTransform)
            width = Int(abs(size.width))
            height = Int(abs(size.height))
        }

        let thumb = await videoThumbnail(asset: asset)

        return PreparedMedia(
            kind: .video,
            name: "视频 \(shortStamp()).mov",
            mime: "video/quicktime",
            width: width,
            height: height,
            duration: duration.isFinite ? duration : 0,
            payload: data,
            thumbnail: thumb,
            byteSize: data.count
        )
    }

    private static func videoThumbnail(asset: AVAsset) async -> Data? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 640)
        let time = CMTime(seconds: 0.5, preferredTimescale: 600)
        return await withCheckedContinuation { continuation in
            generator.generateCGImageAsynchronously(for: time) { cgImage, _, _ in
                guard let cgImage else {
                    continuation.resume(returning: nil)
                    return
                }
                let image = UIImage(cgImage: cgImage)
                continuation.resume(returning: thumbnail(from: image, maxSide: maxThumbSide))
            }
        }
    }

    // MARK: 工具

    private static func thumbnail(from image: UIImage, maxSide: CGFloat) -> Data? {
        let side = max(image.size.width, image.size.height, 1)
        let scale = min(1, maxSide / side)
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = draw(image, into: target) ?? image
        return resized.jpegData(compressionQuality: 0.72)
    }

    private static func draw(_ image: UIImage, into size: CGSize) -> UIImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func shortStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMdd-HHmm"
        return formatter.string(from: Date())
    }
}
