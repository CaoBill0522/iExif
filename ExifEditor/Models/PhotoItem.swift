import ImageIO
import Observation
import SwiftUI
import UniformTypeIdentifiers

/// 一张已载入的照片：原始文件数据 + 解析出的元数据。
@Observable
final class PhotoItem: Identifiable {
    let id = UUID()
    /// 来自相册时的 PHAsset.localIdentifier；从「文件」导入时为 nil。
    let assetIdentifier: String?
    let filename: String
    private(set) var data: Data
    private(set) var typeIdentifier: String
    private(set) var properties: [String: Any]
    private(set) var original: PhotoMetadata
    private(set) var pixelSize: CGSize?
    let thumbnail: UIImage?
    /// 实况照片的视频部分（临时文件）
    let pairedVideoURL: URL?

    init(data: Data, filename: String, assetIdentifier: String?, pairedVideoURL: URL? = nil) throws {
        self.pairedVideoURL = pairedVideoURL
        let result = try MetadataService.read(data)
        self.data = data
        self.filename = filename
        self.assetIdentifier = assetIdentifier
        typeIdentifier = result.typeIdentifier
        properties = result.properties
        original = result.metadata
        if let w = result.pixelWidth, let h = result.pixelHeight { pixelSize = CGSize(width: w, height: h) }
        thumbnail = Self.makeThumbnail(data)
    }

    var type: UTType? { UTType(typeIdentifier) }

    var formatName: String {
        type?.preferredFilenameExtension?.uppercased() ?? typeIdentifier
    }

    /// 写入成功后用新数据替换，使后续编辑以最新文件为准。
    func replaceData(_ newData: Data) {
        guard let result = try? MetadataService.read(newData) else { return }
        data = newData
        typeIdentifier = result.typeIdentifier
        properties = result.properties
        original = result.metadata
    }

    var isLivePhoto: Bool { pairedVideoURL != nil }

    /// MakerNote 中的实况配对编号
    var liveIdentifier: String? {
        (properties[kCGImagePropertyMakerAppleDictionary as String] as? [String: Any])?["17"] as? String
    }

    /// 实况照片无损保存时 MakerNote 只能整体保留（配对编号在里面），此时忽略“清除 MakerNote”。
    func keepsMakerNoteForLive(plan: OutputPlan, stripMakerNote: Bool) -> Bool {
        isLivePhoto && stripMakerNote && !plan.reencodes
    }

    @MainActor
    func outputPlan(fields: Set<MetadataField>, values: PhotoMetadata, matchResolution: Bool) -> OutputPlan {
        var final = original
        final.apply(fields, from: values)
        return OutputPlanner.plan(sourceType: type, sourcePixelSize: pixelSize, final: final,
                                  formatMode: UserDefaults.standard.outputFormatMode, matchResolution: matchResolution)
    }

    struct Rendered {
        let data: Data
        let filename: String
        let pairedVideoURL: URL?
    }

    /// 生成最终文件：按需转格式 / 改尺寸，写入元数据，实况视频同步元数据。
    @MainActor
    func render(fields: Set<MetadataField>, values: PhotoMetadata, stripMakerNote: Bool,
                matchResolution: Bool, includeVideo: Bool = true) async throws -> Rendered {
        let plan = outputPlan(fields: fields, values: values, matchResolution: matchResolution)
        let source = data, original = original
        let liveID = isLivePhoto ? liveIdentifier : nil
        let strip = stripMakerNote && !keepsMakerNoteForLive(plan: plan, stripMakerNote: stripMakerNote)

        let output = try await Task.detached(priority: .userInitiated) {
            var working = source
            var stripLater = strip
            if plan.reencodes {
                working = try ImageTranscoder.transcode(source, to: plan.type, pixelSize: plan.pixelSize,
                                                        makerNote: strip ? .onlyLiveIdentifier(liveID) : .keep)
                stripLater = false
            }
            return try MetadataService.write(working, fields: fields, values: values, original: original,
                                             stripMakerNote: stripLater)
        }.value

        var name = filename
        if plan.reencodes {
            name = (filename as NSString).deletingPathExtension + "." + plan.fileExtension
        }
        var video: URL?
        if includeVideo, let pairedVideoURL {
            var final = original
            final.apply(fields, from: values)
            video = try await LivePhotoVideo.rewrite(pairedVideoURL, fields: fields, final: final)
        }
        return Rendered(data: output, filename: name, pairedVideoURL: video)
    }

    private static func makeThumbnail(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 600,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary).map(UIImage.init(cgImage:))
    }
}

// MARK: - 载入

enum PhotoLoader {
    static func load(fileURLs: [URL]) -> (items: [PhotoItem], failures: Int) {
        var items: [PhotoItem] = []
        var failures = 0
        for url in fileURLs {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url),
               let item = try? PhotoItem(data: data, filename: url.lastPathComponent, assetIdentifier: nil) {
                items.append(item)
            } else {
                failures += 1
            }
        }
        return (items, failures)
    }
}
