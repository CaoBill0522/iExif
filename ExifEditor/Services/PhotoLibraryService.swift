import CoreLocation
import Photos
import UniformTypeIdentifiers

enum PhotoLibraryError: LocalizedError {
    case accessDenied
    case assetNotFound
    case resourceMissing

    var errorDescription: String? {
        switch self {
        case .accessDenied: String(localized: "Photo library access is off. Turn it on in Settings to save photos.")
        case .assetNotFound: String(localized: "The original photo can no longer be found in your library.")
        case .resourceMissing: String(localized: "Couldn't load the original image data.")
        }
    }
}

enum PhotoLibraryService {
    static func requestReadWriteAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }

    static func requestAddAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        return status == .authorized || status == .limited
    }

    static func asset(withIdentifier identifier: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject
    }

    /// 读取照片当前版本的原始文件（在「照片」里编辑过的取渲染后的全尺寸图）；实况照片同时导出视频。
    static func loadImageData(for asset: PHAsset) async throws -> (data: Data, filename: String, pairedVideo: URL?) {
        let resources = PHAssetResource.assetResources(for: asset)
        let edited = resources.contains { $0.type == .fullSizePhoto }
        guard let resource = resources.first(where: { $0.type == .fullSizePhoto })
            ?? resources.first(where: { $0.type == .photo })
        else { throw PhotoLibraryError.resourceMissing }

        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        var data = Data()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHAssetResourceManager.default().requestData(for: resource, options: options) { chunk in
                data.append(chunk)
            } completionHandler: { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
        // fullSizePhoto 的文件名通常是 FullSizeRender.jpg，改用原始文件名 + 实际扩展名。
        let original = resources.first(where: { $0.type == .photo })?.originalFilename ?? resource.originalFilename
        let ext = UTType(resource.uniformTypeIdentifier)?.preferredFilenameExtension
        let filename = ext.map { (original as NSString).deletingPathExtension + "." + $0 } ?? original

        var videoURL: URL?
        if asset.mediaSubtypes.contains(.photoLive),
           let video = (edited ? resources.first(where: { $0.type == .fullSizePairedVideo }) : nil)
            ?? resources.first(where: { $0.type == .pairedVideo }) {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = dir.appendingPathComponent((original as NSString).deletingPathExtension + ".MOV")
            try await PHAssetResourceManager.default().writeData(for: video, toFile: url, options: options)
            videoURL = url
        }
        return (data, filename, videoURL)
    }

    /// 以新照片保存，返回新照片的 localIdentifier。
    @discardableResult
    static func saveNewPhoto(data: Data, filename: String, pairedVideo: URL? = nil,
                             creationDate: Date?, location: GeoLocation?) async throws -> String? {
        guard await requestAddAccess() else { throw PhotoLibraryError.accessDenied }
        var identifier: String?
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            options.originalFilename = filename
            request.addResource(with: .photo, data: data, options: options)
            if let pairedVideo {
                let videoOptions = PHAssetResourceCreationOptions()
                videoOptions.originalFilename = (filename as NSString).deletingPathExtension + ".MOV"
                request.addResource(with: .pairedVideo, fileURL: pairedVideo, options: videoOptions)
            }
            if let creationDate { request.creationDate = creationDate }
            request.location = location.map(Self.clLocation)
            identifier = request.placeholderForCreatedAsset?.localIdentifier
        }
        return identifier
    }

    /// 删除照片，系统会弹出确认框；用户取消时抛出错误。
    static func deleteAssets(withIdentifiers identifiers: [String]) async throws {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        guard assets.count > 0 else { throw PhotoLibraryError.assetNotFound }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets)
        }
    }

    /// 只修改相册层面的时间 / 位置，不动文件。`location` 为 .some(nil) 表示清除位置。
    static func updateAlbumInfo(assetIdentifiers: [String], date: @escaping @Sendable (PHAsset) -> Date?, location: GeoLocation??) async throws {
        guard await requestReadWriteAccess() else { throw PhotoLibraryError.accessDenied }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: assetIdentifiers, options: nil)
        guard assets.count > 0 else { throw PhotoLibraryError.assetNotFound }
        var list: [PHAsset] = []
        assets.enumerateObjects { asset, _, _ in list.append(asset) }
        try await PHPhotoLibrary.shared().performChanges {
            for asset in list {
                let request = PHAssetChangeRequest(for: asset)
                if let newDate = date(asset) { request.creationDate = newDate }
                if let location { request.location = location.map(Self.clLocation) }
            }
        }
    }

    static func clLocation(_ l: GeoLocation) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: l.latitude, longitude: l.longitude),
            altitude: l.altitude ?? 0,
            horizontalAccuracy: 0,
            verticalAccuracy: l.altitude == nil ? -1 : 0,
            course: l.direction ?? -1,
            speed: -1,
            timestamp: Date()
        )
    }
}
