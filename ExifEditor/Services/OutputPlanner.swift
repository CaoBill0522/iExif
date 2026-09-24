import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 一张照片最终要输出成什么格式、什么尺寸。
struct OutputPlan: Equatable {
    var type: UTType
    /// 目标像素尺寸（与原图同方向）；nil 表示不改尺寸
    var pixelSize: CGSize?
    /// 需要重新编码（换格式或改尺寸）
    var reencodes: Bool
    /// 目标比原图大，会放大
    var upscales: Bool
    /// 需要裁掉一部分边缘以符合相机比例
    var crops: Bool

    var fileExtension: String {
        type == .heic ? "HEIC" : type == .jpeg ? "JPG" : (type.preferredFilenameExtension ?? "jpg").uppercased()
    }
}

@MainActor
enum OutputPlanner {
    /// 根据编辑后的机型 / 镜头决定输出格式和尺寸。找不到对应机型时保持原样。
    static func plan(sourceType: UTType?, sourcePixelSize: CGSize?, final: PhotoMetadata,
                     formatMode: OutputFormatMode, matchResolution: Bool) -> OutputPlan {
        let source = sourceType ?? .jpeg
        let match = DeviceCatalogStore.shared.match(model: final.model, lensModel: final.lensModel)
        var plan = OutputPlan(type: source, pixelSize: nil, reencodes: false, upscales: false, crops: false)
        guard let (device, matchedLens) = match else { return plan }

        // 格式
        let deviceDefault: UTType = device.heif == false ? .jpeg : .heic
        switch formatMode {
        case .followDevice:
            plan.type = deviceDefault
        case .keepOriginal:
            let possible = source == .jpeg || (source == .heic && device.heif != false)
            plan.type = possible ? source : deviceDefault
        }

        // 分辨率：优先用匹配到的镜头，否则用主摄
        if matchResolution, let sourceSize = sourcePixelSize, sourceSize.width > 0, sourceSize.height > 0,
           let lens = matchedLens ?? device.lenses.first(where: { $0.kind == .wide }) ?? device.lenses.first,
           let w = lens.pixelWidth, let h = lens.pixelHeight {
            let target = targetSize(for: sourceSize, long: CGFloat(w), short: CGFloat(h))
            if target != sourceSize {
                plan.pixelSize = target
                plan.upscales = max(target.width, target.height) > max(sourceSize.width, sourceSize.height)
                plan.crops = abs(target.width / target.height - sourceSize.width / sourceSize.height) > 0.01
            }
        }

        plan.reencodes = plan.type != source || plan.pixelSize != nil
        return plan
    }

    /// 选择最接近原图的相机比例（4:3、16:9、1:1），返回与原图同方向的尺寸。
    static func targetSize(for source: CGSize, long: CGFloat, short: CGFloat) -> CGSize {
        let sourceLong = max(source.width, source.height), sourceShort = min(source.width, source.height)
        let ratio = sourceLong / sourceShort
        let candidates: [(ratio: CGFloat, long: CGFloat, short: CGFloat)] = [
            (long / short, long, short),
            (16.0 / 9.0, long, (long * 9 / 16).rounded()),
            (1, short, short),
        ]
        let best = candidates.min { abs(log($0.ratio) - log(ratio)) < abs(log($1.ratio) - log(ratio)) }!
        return source.width >= source.height
            ? CGSize(width: best.long, height: best.short)
            : CGSize(width: best.short, height: best.long)
    }
}

/// 转格式 / 改尺寸时的重新编码。
enum ImageTranscoder {
    enum MakerNote {
        case keep
        /// 清除 MakerNote，只保留实况照片的配对编号（nil 表示全部清除）
        case onlyLiveIdentifier(String?)
    }

    static let quality = 0.9

    static func transcode(_ data: Data, to type: UTType, pixelSize: CGSize?, makerNote: MakerNote) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              var image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              var properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        else { throw MetadataError.unreadableImage }

        if let pixelSize {
            image = try resize(image, to: pixelSize)
            var exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
            exif[kCGImagePropertyExifPixelXDimension as String] = Int(pixelSize.width)
            exif[kCGImagePropertyExifPixelYDimension as String] = Int(pixelSize.height)
            properties[kCGImagePropertyExifDictionary as String] = exif
        }
        if type != .png { properties.removeValue(forKey: kCGImagePropertyPNGDictionary as String) }
        if case .onlyLiveIdentifier(let id) = makerNote {
            properties[kCGImagePropertyMakerAppleDictionary as String] = id.map { ["17": $0] }
        }
        properties[kCGImageDestinationLossyCompressionQuality as String] = quality

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil)
        else { throw MetadataError.writeFailed }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw MetadataError.writeFailed }
        return output as Data
    }

    /// 居中裁切到目标比例后缩放。
    private static func resize(_ image: CGImage, to size: CGSize) throws -> CGImage {
        let w = CGFloat(image.width), h = CGFloat(image.height)
        let targetRatio = size.width / size.height
        var crop = CGRect(x: 0, y: 0, width: w, height: h)
        if w / h > targetRatio {
            crop.size.width = (h * targetRatio).rounded()
            crop.origin.x = ((w - crop.width) / 2).rounded()
        } else {
            crop.size.height = (w / targetRatio).rounded()
            crop.origin.y = ((h - crop.height) / 2).rounded()
        }
        let cropped = image.cropping(to: crop) ?? image
        let space = image.colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                                      bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { throw MetadataError.writeFailed }
        context.interpolationQuality = .high
        context.draw(cropped, in: CGRect(origin: .zero, size: size))
        guard let result = context.makeImage() else { throw MetadataError.writeFailed }
        return result
    }
}
