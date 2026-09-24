import Photos
import SwiftUI

/// 照片网格：点按打开编辑，「选择」模式下点按或滑动多选后批量修改。
struct AssetGrid: View {
    let assets: PHFetchResult<PHAsset>
    var header: AnyView? = nil

    @Environment(EditorLauncher.self) private var launcher
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var isSelecting = false
    /// 按选择顺序排列的 localIdentifier
    @State private var selection: [String] = []

    // 滑动多选
    @State private var drag: DragSelection?
    /// 手势被系统取消时 onEnded 不会调用，用 GestureState 的自动复位来兜底。
    @GestureState private var isDragging = false
    @State private var dragIgnored = false
    @State private var autoScroll: AutoScroll?
    /// 网格位置随滚动每帧变化，放在非观察的引用里，避免滚动时整页重绘。
    @State private var geometry = GridGeometry()

    private let spacing: CGFloat = 2
    private let edgeZone: CGFloat = 70

    var body: some View {
        GeometryReader { viewport in
            scrollingGrid(size: viewport.size)
        }
        .overlay {
            if assets.count == 0 {
                ContentUnavailableView("No Photos", systemImage: "photo.on.rectangle")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelecting { selectionBar }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSelecting ? "Cancel" : "Select") {
                    isSelecting.toggle()
                    selection = []
                    endDrag()
                }
                .disabled(assets.count == 0)
            }
        }
    }

    private static let viewportSpace = "assetGridViewport"

    // MARK: 网格

    private func layout(for width: CGFloat) -> (columns: Int, cellSide: CGFloat) {
        let columns = columnCount(for: width)
        return (columns, (width - spacing * CGFloat(columns - 1)) / CGFloat(columns))
    }

    private func scrollingGrid(size: CGSize) -> some View {
        let (columns, cellSide) = layout(for: size.width)
        return ScrollViewReader { proxy in
            ScrollView {
                if let header { header }
                grid(columns: columns, cellSide: cellSide)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.viewportSpace)) } action: { frame in
                        geometry.frame = frame
                        // 自动滚动时手指没动，但格子动了，需要按新位置重新计算选区。
                        if drag != nil, let location = geometry.lastLocation { updateDrag(to: location) }
                    }
            }
            .coordinateSpace(.named(Self.viewportSpace))
            .scrollDisabled(drag != nil)
            .onAppear { updateLayout(columns: columns, cellSide: cellSide, height: size.height) }
            .onChange(of: size) { _, newSize in
                let newLayout = layout(for: newSize.width)
                updateLayout(columns: newLayout.columns, cellSide: newLayout.cellSide, height: newSize.height)
            }
            .simultaneousGesture(dragGesture(proxy: proxy), including: isSelecting ? .all : .subviews)
            .onChange(of: isDragging) { _, dragging in
                if !dragging { endDrag() }
            }
        }
    }

    private func grid(columns: Int, cellSide: CGFloat) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns), spacing: spacing) {
            ForEach(0..<assets.count, id: \.self) { index in
                cell(assets.object(at: index), side: cellSide)
            }
        }
    }

    private func cell(_ asset: PHAsset, side: CGFloat) -> some View {
        AssetThumbnail(asset: asset, side: side)
            .overlay(alignment: .topTrailing) {
                if asset.mediaSubtypes.contains(.photoLive) {
                    Image(systemName: "livephoto")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .shadow(radius: 1)
                        .padding(5)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isSelecting { selectionBadge(for: asset) }
            }
            .contentShape(Rectangle())
            .onTapGesture { tap(asset) }
            // 长按预览：系统菜单自带震动反馈
            .contextMenu {
                Button("Edit", systemImage: "slider.horizontal.3") {
                    Task { await launcher.open(assets: [asset]) }
                }
                if !isSelecting {
                    Button("Select", systemImage: "checkmark.circle") {
                        isSelecting = true
                        selection = [asset.localIdentifier]
                    }
                }
            } preview: {
                AssetPreview(asset: asset)
            }
    }

    private func updateLayout(columns: Int, cellSide: CGFloat, height: CGFloat) {
        geometry.columns = columns
        geometry.cellSide = cellSide
        geometry.viewportHeight = height
    }

    private func columnCount(for width: CGFloat) -> Int {
        let minimum: CGFloat = sizeClass == .regular ? 140 : 96
        return max(1, Int((width + spacing) / (minimum + spacing)))
    }

    // MARK: 点按

    private func tap(_ asset: PHAsset) {
        guard isSelecting else {
            Task { await launcher.open(assets: [asset]) }
            return
        }
        if let index = selection.firstIndex(of: asset.localIdentifier) {
            selection.remove(at: index)
        } else if selection.count < EditorLauncher.maxSelection {
            selection.append(asset.localIdentifier)
        }
    }

    // MARK: 滑动多选

    struct DragSelection {
        let anchor: Int
        /// 起点已选中时，本次滑动为取消选择
        let deselecting: Bool
        /// 开始滑动前的选择
        let baseline: [String]
    }

    private enum AutoScroll { case up, down }

    /// 横向起手判定为多选（此时禁止滚动），竖向起手交给滚动。
    private func dragGesture(proxy: ScrollViewProxy) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .named(Self.viewportSpace))
            .updating($isDragging) { _, state, _ in state = true }
            .onChanged { value in
                if drag == nil {
                    guard !dragIgnored else { return }
                    let t = value.translation
                    guard abs(t.width) > abs(t.height), let anchor = index(at: value.startLocation) else {
                        dragIgnored = true
                        return
                    }
                    let id = assets.object(at: anchor).localIdentifier
                    drag = DragSelection(anchor: anchor, deselecting: selection.contains(id), baseline: selection)
                }
                geometry.lastLocation = value.location
                updateDrag(to: value.location)
                updateAutoScroll(at: value.location, movingDown: value.translation.height > 0, proxy: proxy)
            }
            .onEnded { _ in endDrag() }
    }

    private func endDrag() {
        drag = nil
        dragIgnored = false
        autoScroll = nil
        geometry.lastLocation = nil
    }

    /// 视口坐标 → 照片序号（超出网格时夹到最近的格子）。
    private func index(at point: CGPoint) -> Int? {
        let frame = geometry.frame
        guard assets.count > 0, geometry.columns > 0, geometry.cellSide > 0, point.y >= frame.minY else { return nil }
        let step = geometry.cellSide + spacing
        let column = min(max(Int((point.x - frame.minX) / step), 0), geometry.columns - 1)
        let row = max(Int((point.y - frame.minY) / step), 0)
        return min(row * geometry.columns + column, assets.count - 1)
    }

    private func updateDrag(to location: CGPoint) {
        guard let drag, let current = index(at: CGPoint(x: location.x, y: max(location.y, geometry.frame.minY))) else { return }
        let range = drag.anchor <= current ? Array(drag.anchor...current) : Array((current...drag.anchor).reversed())
        let ids = range.map { assets.object(at: $0).localIdentifier }
        if drag.deselecting {
            let removed = Set(ids)
            selection = drag.baseline.filter { !removed.contains($0) }
        } else {
            let existing = Set(drag.baseline)
            let added = ids.filter { !existing.contains($0) }
            selection = Array((drag.baseline + added).prefix(EditorLauncher.maxSelection))
        }
    }

    /// 手指靠近上下边缘时逐行自动滚动。
    private func updateAutoScroll(at location: CGPoint, movingDown: Bool, proxy: ScrollViewProxy) {
        // 手指朝边缘方向拖动并进入边缘区域时才滚动，避免起手就在边缘附近时误触发。
        let direction: AutoScroll? = movingDown && location.y > geometry.viewportHeight - edgeZone ? .down
            : !movingDown && location.y < edgeZone ? .up : nil
        guard direction != autoScroll else { return }
        autoScroll = direction
        guard let direction else { return }
        Task { @MainActor in
            while autoScroll == direction, drag != nil {
                let edgeY = direction == .down ? geometry.viewportHeight - 1 : max(geometry.frame.minY, 1)
                if let edgeIndex = index(at: CGPoint(x: 1, y: edgeY)) {
                    let target = direction == .down
                        ? min(edgeIndex + geometry.columns, assets.count - 1)
                        : max(edgeIndex - geometry.columns, 0)
                    withAnimation(.linear(duration: 0.12)) {
                        proxy.scrollTo(target, anchor: direction == .down ? .bottom : .top)
                    }
                }
                try? await Task.sleep(for: .milliseconds(120))
            }
        }
    }

    // MARK: 子视图

    @ViewBuilder
    private func selectionBadge(for asset: PHAsset) -> some View {
        let order = selection.firstIndex(of: asset.localIdentifier)
        ZStack {
            Circle().fill(order == nil ? Color.black.opacity(0.25) : Color.accentColor)
            Circle().strokeBorder(.white, lineWidth: 1.5)
            if let order {
                Text(verbatim: "\(order + 1)").font(.caption2.bold()).foregroundStyle(.white)
            }
        }
        .frame(width: 24, height: 24)
        .padding(6)
    }

    private var selectionBar: some View {
        VStack(spacing: 6) {
            Button {
                let chosen = PHAsset.fetchAssets(withLocalIdentifiers: selection, options: nil)
                var byID: [String: PHAsset] = [:]
                chosen.enumerateObjects { asset, _, _ in byID[asset.localIdentifier] = asset }
                let ordered = selection.compactMap { byID[$0] }
                Task {
                    await launcher.open(assets: ordered)
                    isSelecting = false
                    selection = []
                }
            } label: {
                Text(selection.count <= 1 ? String(localized: "Edit Photo") : String(localized: "Edit \(selection.count) Photos"))
                    .frame(maxWidth: 480)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selection.isEmpty)
            if selection.count >= EditorLauncher.maxSelection {
                Text("Up to 100 photos can be edited at once.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Swipe sideways across photos to select several at once.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}

/// 网格几何信息。普通引用类型（不被观察），滚动时更新不会触发重绘。
private final class GridGeometry {
    var frame: CGRect = .zero
    var columns = 1
    var cellSide: CGFloat = 0
    var viewportHeight: CGFloat = 0
    var lastLocation: CGPoint?
}

struct AssetThumbnail: View {
    let asset: PHAsset
    var side: CGFloat = 110

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?

    var body: some View {
        Color(.secondarySystemFill)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            .clipped()
            .onAppear(perform: load)
            .onDisappear {
                if let requestID { ThumbnailCache.manager.cancelImageRequest(requestID) }
            }
            .onChange(of: asset.localIdentifier) { _, _ in
                image = nil
                load()
            }
    }

    private func load() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        let size = CGSize(width: side * displayScale, height: side * displayScale)
        let id = asset.localIdentifier
        requestID = ThumbnailCache.manager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { result, _ in
            if let result, id == asset.localIdentifier { image = result }
        }
    }
}
