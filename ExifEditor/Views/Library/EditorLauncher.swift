import Observation
import Photos

enum HomeRoute: Hashable {
    case single(UUID)
    case batch
    case album(String)
    case folder(String)
}

/// 「编辑」页的导航状态：从网格、相簿或文件载入照片后推入编辑页。
@MainActor
@Observable
final class EditorLauncher {
    static let maxSelection = 100

    var path: [HomeRoute] = []
    private(set) var items: [PhotoItem] = []
    private(set) var isLoading = false
    var alert: AlertInfo?

    func item(withID id: UUID) -> PhotoItem? {
        items.first { $0.id == id }
    }

    func open(assets: [PHAsset]) async {
        isLoading = true
        defer { isLoading = false }
        var loaded: [PhotoItem] = []
        var failures = 0
        for asset in assets.prefix(Self.maxSelection) {
            do {
                let (data, filename, video) = try await PhotoLibraryService.loadImageData(for: asset)
                loaded.append(try PhotoItem(data: data, filename: filename, assetIdentifier: asset.localIdentifier,
                                            pairedVideoURL: video))
            } catch {
                failures += 1
            }
        }
        show(loaded, failures: failures)
    }

    func open(fileURLs: [URL]) {
        let result = PhotoLoader.load(fileURLs: fileURLs)
        show(result.items, failures: result.failures)
    }

    private func show(_ loaded: [PhotoItem], failures: Int) {
        if failures > 0 {
            alert = AlertInfo(title: String(localized: "Some Photos Couldn't Be Opened"),
                              message: String(localized: "\(failures) items aren't supported images or couldn't be downloaded from iCloud."))
        }
        guard !loaded.isEmpty else { return }
        items = loaded
        path.append(loaded.count == 1 ? .single(loaded[0].id) : .batch)
    }
}
