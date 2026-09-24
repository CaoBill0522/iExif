import Photos
import SwiftUI

/// 「编辑」页：浏览全部照片或相簿，点选后进入编辑。
struct HomeView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case library, albums
        var id: String { rawValue }
        var title: String {
            switch self {
            case .library: String(localized: "Library")
            case .albums: String(localized: "Albums")
            }
        }
    }

    @Environment(PhotoLibraryBrowser.self) private var browser
    @State private var launcher = EditorLauncher()
    @SceneStorage("homeMode") private var mode: Mode = .library
    @State private var showFileImporter = false
    @AppStorage(OnboardingKey.seen) private var onboardingSeen = false

    var body: some View {
        NavigationStack(path: $launcher.path) {
            content
                .navigationTitle(mode.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Picker("View", selection: $mode) {
                            ForEach(Mode.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                        .disabled(!browser.canBrowse)
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showFileImporter = true
                        } label: {
                            Label("Import from Files", systemImage: "folder")
                        }
                    }
                }
                .navigationDestination(for: HomeRoute.self) { route in
                    switch route {
                    case .single(let id):
                        if let item = launcher.item(withID: id) { EditorView(item: item) }
                    case .batch:
                        BatchEditView(items: launcher.items)
                    case .album(let id):
                        AlbumDetailView(collectionID: id)
                    case .folder(let id):
                        FolderView(folderID: id)
                    }
                }
        }
        .environment(launcher)
        .overlay {
            if launcher.isLoading {
                ProgressView("Loading Photos…")
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.jpeg, .heic, .heif, .png, .image],
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): launcher.open(fileURLs: urls)
            case .failure(let error): launcher.alert = AlertInfo(error: error)
            }
        }
        .alert(item: $launcher.alert) { info in
            Alert(title: Text(info.title), message: Text(info.message))
        }
        // 引导页关闭后再申请相册权限，避免系统弹窗挡住引导页
        .task(id: onboardingSeen) {
            if onboardingSeen { await browser.requestAccessIfNeeded() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch browser.status {
        case .notDetermined:
            ProgressView()
        case .authorized, .limited:
            // 放在同一个 ZStack 里，切换时新旧两页交叉淡入淡出。
            ZStack {
                switch mode {
                case .library:
                    AssetGrid(assets: browser.allPhotos, header: browser.status == .limited ? AnyView(limitedBanner) : nil)
                        .transition(.opacity)
                case .albums:
                    AlbumListView(folderID: nil)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: mode)
        default:
            ContentUnavailableView {
                Label("Photo Library Access Needed", systemImage: "photo.badge.exclamationmark")
            } description: {
                Text("Allow access to your photo library in Settings to browse and edit your photos. You can still import from Files.")
            } actions: {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .buttonStyle(.borderedProminent)
                Button("Import from Files") { showFileImporter = true }
            }
        }
    }

    private var limitedBanner: some View {
        HStack {
            Text("You've allowed access to some photos only.")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Manage") { browser.presentLimitedLibraryPicker() }
        }
        .font(.footnote)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
