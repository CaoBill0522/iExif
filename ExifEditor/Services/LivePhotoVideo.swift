import AVFoundation
import Foundation

/// 实况照片的视频部分：同步拍摄时间、地点和机型到 QuickTime 元数据。
/// 使用 Passthrough 导出，只重写元数据，视频不重新压缩；配对编号（content.identifier）保持不变。
enum LivePhotoVideo {
    static func rewrite(_ url: URL, fields: Set<MetadataField>, final: PhotoMetadata) async throws -> URL {
        let relevant: Set<MetadataField> = [.device, .dateTime, .location]
        guard !fields.isDisjoint(with: relevant) else { return url }

        let asset = AVURLAsset(url: url)
        var items = try await asset.load(.metadata)

        func replace(_ identifier: AVMetadataIdentifier, _ value: String?) {
            items.removeAll { $0.identifier == identifier }
            guard let value else { return }
            let item = AVMutableMetadataItem()
            item.identifier = identifier
            item.value = value as NSString
            item.dataType = kCMMetadataBaseDataType_UTF8 as String
            items.append(item)
        }

        if fields.contains(.device) {
            replace(.quickTimeMetadataMake, final.make)
            replace(.quickTimeMetadataModel, final.model)
            replace(.quickTimeMetadataSoftware, final.software)
        }
        if fields.contains(.dateTime) {
            replace(.quickTimeMetadataCreationDate, final.dateTaken.map { quickTimeDate($0, in: final.timeZone) })
        }
        if fields.contains(.location) {
            replace(.quickTimeMetadataLocationISO6709, final.location.map(iso6709))
        }

        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent(url.lastPathComponent)
        try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)

        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough)
        else { throw MetadataError.writeFailed }
        session.metadata = items
        session.shouldOptimizeForNetworkUse = false
        if #available(iOS 18.0, *) {
            try await session.export(to: output, as: .mov)
        } else {
            session.outputURL = output
            session.outputFileType = .mov
            await session.export()
            if let error = session.error { throw error }
        }
        return output
    }

    /// 例如 2017-05-01T10:20:30+0800
    static func quickTimeDate(_ date: Date, in tz: TimeZone) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return f.string(from: date)
    }

    /// 例如 +31.2304+121.4737+003.500/
    static func iso6709(_ l: GeoLocation) -> String {
        var s = String(format: "%+08.4f%+09.4f", l.latitude, l.longitude)
        if let altitude = l.altitude { s += String(format: "%+08.3f", altitude) }
        return s + "/"
    }
}
