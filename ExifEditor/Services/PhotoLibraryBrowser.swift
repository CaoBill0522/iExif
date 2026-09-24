import Observation
import Photos
import PhotosUI
import UIKit

/// 相册浏览：授权状态、变化监听、相簿目录。
@MainActor
@Observable
final class PhotoLibraryBrowser: NSObject, PHPhotoLibraryChangeObserver {
    private(set) var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    /// 全部照片，相册变化时按增量更新。
    private(set) var allPhotos = PHFetchResult<PHAsset>()
    /// 顶层相簿目录，后台计算并缓存。
    private(set) var albumSections: [AlbumSection] = []
    /// 最近一次相册变化，相簿详情页用它做增量更新。
    private(set) var lastChange: PHChange?
    /// 相册内容变化时递增，视图据此检查自己的列表。
    private(set) var changeCount = 0
    private var registered = false
    private var albumReloadTask: Task<Void, Never>?

    var canBrowse: Bool { status == .authorized || status == .limited }

    func requestAccessIfNeeded() async {
        if status == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        guard canBrowse, !registered else { return }
        PHPhotoLibrary.shared().register(self)
        registered = true
        allPhotos = Self.allPhotos()
        await reloadAlbums()
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            lastChange = changeInstance
            // iCloud 同步时变化通知很频繁：只有影响到当前列表时才替换，避免整页重绘。
            if let details = changeInstance.changeDetails(for: allPhotos) {
                allPhotos = details.fetchResultAfterChanges
            }
            changeCount += 1
            scheduleAlbumReload()
        }
    }

    /// 合并 1 秒内的多次变化，只重算一次相簿目录。
    private func scheduleAlbumReload() {
        albumReloadTask?.cancel()
        albumReloadTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await reloadAlbums()
        }
    }

    private func reloadAlbums() async {
        let sections = await Self.loadAlbumSections(folderID: nil)
        if sections != albumSections { albumSections = sections }
    }

    /// 在后台线程读取相簿目录（每个相簿都要查一次张数，放主线程会卡）。
    nonisolated static func loadAlbumSections(folderID: String?) async -> [AlbumSection] {
        await Task.detached(priority: .userInitiated) { albumSections(folderID: folderID) }.value
    }

    /// 部分访问时让用户追加可访问的照片。
    func presentLimitedLibraryPicker() {
        let root = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first
        guard var top = root else { return }
        while let presented = top.presentedViewController { top = presented }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: top)
    }

    // MARK: 读取

    nonisolated static var imageOptions: PHFetchOptions {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return options
    }

    nonisolated static func allPhotos() -> PHFetchResult<PHAsset> {
        PHAsset.fetchAssets(with: imageOptions)
    }

    nonisolated static func photos(in collection: PHAssetCollection) -> PHFetchResult<PHAsset> {
        PHAsset.fetchAssets(in: collection, options: imageOptions)
    }

    nonisolated static func collection(withIdentifier id: String) -> PHAssetCollection? {
        PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil).firstObject
    }

    nonisolated static func folder(withIdentifier id: String) -> PHCollectionList? {
        PHCollectionList.fetchCollectionLists(withLocalIdentifiers: [id], options: nil).firstObject
    }

    /// 相簿页的分组。`folderID` 为 nil 时是顶层（我的相簿 + 媒体类型）。
    nonisolated static func albumSections(folderID: String?) -> [AlbumSection] {
        if let folderID, let folder = folder(withIdentifier: folderID) {
            return [AlbumSection(id: "folder", title: nil, entries: entries(in: PHCollection.fetchCollections(in: folder, options: nil)))]
        }
        var sections: [AlbumSection] = []
        let mine = entries(in: PHCollectionList.fetchTopLevelUserCollections(with: nil))
        if !mine.isEmpty {
            sections.append(AlbumSection(id: "mine", title: String(localized: "My Albums"), entries: mine))
        }
        let smart = smartSubtypes.compactMap { subtype -> AlbumEntry? in
            guard let collection = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: subtype, options: nil).firstObject
            else { return nil }
            return albumEntry(collection)
        }
        if !smart.isEmpty {
            sections.append(AlbumSection(id: "smart", title: String(localized: "Media Types"), entries: smart))
        }
        return sections
    }

    nonisolated private static let smartSubtypes: [PHAssetCollectionSubtype] = [
        .smartAlbumFavorites, .smartAlbumRecentlyAdded, .smartAlbumSelfPortraits, .smartAlbumDepthEffect,
        .smartAlbumLivePhotos, .smartAlbumPanoramas, .smartAlbumLongExposures, .smartAlbumBursts,
        .smartAlbumRAW, .smartAlbumScreenshots,
    ]

    nonisolated private static func entries(in collections: PHFetchResult<PHCollection>) -> [AlbumEntry] {
        var result: [AlbumEntry] = []
        collections.enumerateObjects { collection, _, _ in
            if let album = collection as? PHAssetCollection, let entry = albumEntry(album) {
                result.append(entry)
            } else if let folder = collection as? PHCollectionList {
                result.append(AlbumEntry(id: folder.localIdentifier, title: folder.localizedTitle ?? "",
                                         count: PHCollection.fetchCollections(in: folder, options: nil).count,
                                         cover: nil, isFolder: true))
            }
        }
        return result
    }

    /// 空相簿不显示。
    nonisolated private static func albumEntry(_ album: PHAssetCollection) -> AlbumEntry? {
        let assets = photos(in: album)
        guard assets.count > 0 else { return nil }
        return AlbumEntry(id: album.localIdentifier, title: album.localizedTitle ?? "",
                          count: assets.count, cover: assets.firstObject, isFolder: false)
    }
}

struct AlbumSection: Identifiable, Equatable {
    let id: String
    let title: String?
    let entries: [AlbumEntry]
}

struct AlbumEntry: Identifiable, Equatable {
    let id: String
    let title: String
    /// 相簿为照片数，文件夹为子项数。
    let count: Int
    let cover: PHAsset?
    let isFolder: Bool
}

/// 缩略图共用的图片管理器。
enum ThumbnailCache {
    static let manager = PHCachingImageManager()
}
