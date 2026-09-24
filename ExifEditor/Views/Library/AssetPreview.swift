import Photos
import PhotosUI
import SwiftUI

/// 长按照片时的大图预览；实况照片自动播放。
struct AssetPreview: View {
    let asset: PHAsset

    @State private var image: UIImage?
    @State private var livePhoto: PHLivePhoto?

    /// 预览尺寸按照片比例，长边不超过 420pt。
    private var size: CGSize {
        let w = CGFloat(max(asset.pixelWidth, 1)), h = CGFloat(max(asset.pixelHeight, 1))
        let scale = 420 / max(w, h)
        return CGSize(width: w * scale, height: h * scale)
    }

    var body: some View {
        ZStack {
            if let livePhoto {
                LivePhotoPlayer(livePhoto: livePhoto)
            } else if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Color(.secondarySystemBackground)
                ProgressView()
            }
        }
        .frame(width: size.width, height: size.height)
        .overlay(alignment: .topLeading) {
            if asset.mediaSubtypes.contains(.photoLive) {
                Image(systemName: "livephoto")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
                    .padding(10)
            }
        }
        .task { await load() }
    }

    private func load() async {
        let target = CGSize(width: size.width * 3, height: size.height * 3)
        if asset.mediaSubtypes.contains(.photoLive) {
            let options = PHLivePhotoRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            for await result in livePhotos(target: target, options: options) {
                livePhoto = result
            }
        } else {
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            for await result in images(target: target, options: options) {
                image = result
            }
        }
    }

    /// opportunistic 模式会先回调低清图再回调高清图。
    private func images(target: CGSize, options: PHImageRequestOptions) -> AsyncStream<UIImage> {
        AsyncStream { continuation in
            let id = PHImageManager.default().requestImage(for: asset, targetSize: target, contentMode: .aspectFit,
                                                           options: options) { result, info in
                if let result { continuation.yield(result) }
                if (info?[PHImageResultIsDegradedKey] as? Bool) != true { continuation.finish() }
            }
            continuation.onTermination = { _ in PHImageManager.default().cancelImageRequest(id) }
        }
    }

    private func livePhotos(target: CGSize, options: PHLivePhotoRequestOptions) -> AsyncStream<PHLivePhoto> {
        AsyncStream { continuation in
            let id = PHImageManager.default().requestLivePhoto(for: asset, targetSize: target, contentMode: .aspectFit,
                                                               options: options) { result, info in
                if let result { continuation.yield(result) }
                if (info?[PHImageResultIsDegradedKey] as? Bool) != true { continuation.finish() }
            }
            continuation.onTermination = { _ in PHImageManager.default().cancelImageRequest(id) }
        }
    }
}

/// PHLivePhotoView 包装，出现后自动完整播放一次。
private struct LivePhotoPlayer: UIViewRepresentable {
    let livePhoto: PHLivePhoto

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ view: PHLivePhotoView, context: Context) {
        guard view.livePhoto != livePhoto else { return }
        view.livePhoto = livePhoto
        view.startPlayback(with: .full)
    }
}
