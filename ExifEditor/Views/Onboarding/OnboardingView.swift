import SwiftUI

enum OnboardingKey {
    static let seen = "onboardingSeen"
}

/// 首次启动的功能介绍与操作指引。
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(OnboardingKey.seen) private var seen = false
    @State private var page = 0

    private struct Page: Identifiable {
        let id: Int
        let title: LocalizedStringKey
        let subtitle: LocalizedStringKey
        let points: [(icon: String, text: LocalizedStringKey)]
        let visual: AnyView
    }

    private var pages: [Page] {
        [
            Page(id: 0,
                 title: "Welcome to iExif",
                 subtitle: "View and change the capture info stored in your photos, all on your device.",
                 points: [("photo.on.rectangle.angled", "Browse your whole library and albums"),
                          ("checkmark.shield", "Lossless: only the metadata is rewritten"),
                          ("lock", "Nothing is uploaded")],
                 visual: AnyView(ScreenshotFrame(name: "onboarding-library"))),
            Page(id: 1,
                 title: "Pick a Device and Lens",
                 subtitle: "Choose from presets for every iPhone and iPad camera. Make, model, lens, aperture and focal length are filled in for you.",
                 points: [("iphone.gen3", "96 devices, from iPhone 4 to the latest models"),
                          ("camera.aperture", "Ultra wide, main, telephoto and front cameras")],
                 visual: AnyView(ScreenshotFrame(name: "onboarding-lens", tapAt: CGPoint(x: 0.3, y: 0.445)))),
            Page(id: 2,
                 title: "Swipe to Select Many",
                 subtitle: "Tap Select, then swipe sideways across photos to select them in one go. Keep dragging to the edge to scroll.",
                 points: [("hand.draw", "Start on a selected photo to deselect instead"),
                          ("square.stack.3d.up", "Edit up to 100 photos at once")],
                 visual: AnyView(SwipeSelectDemo())),
            Page(id: 3,
                 title: "Touch and Hold to Preview",
                 subtitle: "Press and hold any photo to see it larger. Live Photos play in the preview.",
                 points: [("livephoto", "Live Photos are marked in the grid"),
                          ("hand.tap", "Open it for editing right from the preview")],
                 visual: AnyView(LongPressDemo())),
            Page(id: 4,
                 title: "Save Your Way",
                 subtitle: "Save as a new photo or replace the original. The date and location in Photos are updated too.",
                 points: [("livephoto", "Live Photos keep their video"),
                          ("arrow.triangle.2.circlepath", "Converted to the device's format when needed"),
                          ("square.stack", "Save favorite settings as templates")],
                 visual: AnyView(ScreenshotFrame(name: "onboarding-save"))),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip") { finish() }
                    .opacity(page == pages.count - 1 ? 0 : 1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            TabView(selection: $page) {
                ForEach(pages) { item in
                    pageView(item).tag(item.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(pages) { item in
                    Capsule()
                        .fill(item.id == page ? Color.accentColor : Color(.tertiaryLabel))
                        .frame(width: item.id == page ? 20 : 8, height: 8)
                }
            }
            .animation(.spring(duration: 0.3), value: page)
            .padding(.bottom, 16)

            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    finish()
                }
            } label: {
                Text(page < pages.count - 1 ? "Continue" : "Get Started")
                    .font(.headline)
                    .frame(maxWidth: 420)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .background(Color(.systemBackground))
        .interactiveDismissDisabled()
    }

    private func pageView(_ item: Page) -> some View {
        GeometryReader { proxy in
            VStack(spacing: 18) {
                item.visual
                    .frame(maxWidth: .infinity)
                    .frame(height: proxy.size.height * 0.5)
                VStack(spacing: 8) {
                    Text(item.title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text(item.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(item.points.enumerated()), id: \.offset) { _, point in
                        Label {
                            Text(point.text).font(.subheadline)
                        } icon: {
                            Image(systemName: point.icon).foregroundStyle(.tint).frame(width: 24)
                        }
                    }
                }
                .frame(maxWidth: 420, alignment: .leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
            .padding(.top, 8)
        }
    }

    private func finish() {
        seen = true
        dismiss()
    }
}

/// 模拟器截图，套一个手机外框；可选的点击提示动画。
struct ScreenshotFrame: View {
    let name: String
    var tapAt: CGPoint? = nil

    @State private var pulse = false

    /// 截图按语言区分：onboarding-xxx-zh / onboarding-xxx-en
    private var localizedName: String {
        Bundle.main.preferredLocalizations.first?.hasPrefix("zh") == true ? "\(name)-zh" : "\(name)-en"
    }

    var body: some View {
        Image(localizedName)
            .resizable()
            .scaledToFit()
            .overlay {
                if let tapAt {
                    GeometryReader { proxy in
                        ZStack {
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 3)
                                .frame(width: 44, height: 44)
                                .scaleEffect(pulse ? 1.6 : 0.8)
                                .opacity(pulse ? 0 : 0.9)
                            Circle()
                                .fill(Color.accentColor.opacity(0.35))
                                .frame(width: 26, height: 26)
                        }
                        .position(x: proxy.size.width * tapAt.x, y: proxy.size.height * tapAt.y)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color(.separator), lineWidth: 1))
            .shadow(color: .black.opacity(0.15), radius: 16, y: 6)
            .onAppear {
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) { pulse = true }
            }
    }
}
