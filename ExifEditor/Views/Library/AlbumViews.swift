import Photos
import SwiftUI

/// 相簿列表（顶层或某个文件夹内）。
struct AlbumListView: View {
    let folderID: String?

    @Environment(PhotoLibraryBrowser.self) private var browser
    /// 文件夹内的目录（顶层直接用 browser 的缓存）
    @State private var folderSections: [AlbumSection]?

    private var sections: [AlbumSection] {
        folderID == nil ? browser.albumSections : (folderSections ?? [])
    }

    var body: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.entries) { entry in
                        NavigationLink(value: entry.isFolder ? HomeRoute.folder(entry.id) : HomeRoute.album(entry.id)) {
                            AlbumRow(entry: entry)
                        }
                    }
                } header: {
                    if let title = section.title { Text(title) }
                }
            }
        }
        .overlay {
            if sections.isEmpty {
                ContentUnavailableView("No Albums", systemImage: "rectangle.stack")
            }
        }
        .task(id: browser.albumSections) {
            guard let folderID else { return }
            let loaded = await PhotoLibraryBrowser.loadAlbumSections(folderID: folderID)
            if loaded != folderSections { folderSections = loaded }
        }
    }
}

private struct AlbumRow: View {
    let entry: AlbumEntry

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let cover = entry.cover {
                    AssetThumbnail(asset: cover, side: 56)
                } else {
                    Image(systemName: entry.isFolder ? "folder.fill" : "photo.on.rectangle")
                        .font(.title2)
                        .foregroundStyle(.tint)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.secondarySystemFill))
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title).lineLimit(1)
                Text(entry.isFolder ? String(localized: "\(entry.count) items") : String(localized: "\(entry.count) photos"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// 某个相簿的照片网格。
struct AlbumDetailView: View {
    let collectionID: String

    @Environment(PhotoLibraryBrowser.self) private var browser
    @State private var title = ""
    @State private var assets = PHFetchResult<PHAsset>()

    var body: some View {
        AssetGrid(assets: assets)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                guard let collection = PhotoLibraryBrowser.collection(withIdentifier: collectionID) else { return }
                title = collection.localizedTitle ?? ""
                assets = PhotoLibraryBrowser.photos(in: collection)
            }
            .onChange(of: browser.changeCount) {
                // 只在这个相簿的内容真的变了时才替换
                if let details = browser.lastChange?.changeDetails(for: assets) {
                    assets = details.fetchResultAfterChanges
                }
            }
    }
}

/// 文件夹内的相簿列表。
struct FolderView: View {
    let folderID: String

    var body: some View {
        AlbumListView(folderID: folderID)
            .navigationTitle(PhotoLibraryBrowser.folder(withIdentifier: folderID)?.localizedTitle ?? "")
            .navigationBarTitleDisplayMode(.inline)
    }
}
