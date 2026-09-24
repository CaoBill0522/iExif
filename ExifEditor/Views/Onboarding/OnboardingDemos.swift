import SwiftUI

/// 演示用的缩略图格子（渐变色块，不依赖相册）。
private struct DemoTile: View {
    let index: Int

    private static let palettes: [[Color]] = [
        [.blue, .cyan], [.orange, .pink], [.green, .mint], [.purple, .indigo],
        [.teal, .blue], [.pink, .red], [.yellow, .orange], [.indigo, .blue],
        [.mint, .teal], [.red, .orange], [.cyan, .green], [.brown, .orange],
    ]

    var body: some View {
        LinearGradient(colors: Self.palettes[index % Self.palettes.count], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                Image(systemName: ["mountain.2.fill", "leaf.fill", "sun.max.fill", "building.2.fill"][index % 4])
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.85))
            }
    }
}

/// 手指示意
private struct Finger: View {
    var pressed = false

    var body: some View {
        Circle()
            .fill(.white.opacity(0.9))
            .frame(width: 34, height: 34)
            .overlay(Circle().stroke(Color.black.opacity(0.15), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
            .scaleEffect(pressed ? 0.85 : 1)
    }
}

/// 滑动多选：手指横向划过第一行，再斜向下划到第二行，格子依次被选中。
struct SwipeSelectDemo: View {
    private let columns = 4, rows = 3, spacing: CGFloat = 3
    private let cycle = 4.2

    /// 手指路径经过的格子（按顺序）
    private let path = [0, 1, 2, 3, 7, 6, 5]

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
            GeometryReader { proxy in
                let side = min((proxy.size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns),
                               (proxy.size.height - spacing * CGFloat(rows - 1)) / CGFloat(rows))
                let gridWidth = side * CGFloat(columns) + spacing * CGFloat(columns - 1)
                let gridHeight = side * CGFloat(rows) + spacing * CGFloat(rows - 1)
                let origin = CGPoint(x: (proxy.size.width - gridWidth) / 2, y: (proxy.size.height - gridHeight) / 2)
                let state = fingerState(at: t)

                ZStack(alignment: .topLeading) {
                    ForEach(0..<(columns * rows), id: \.self) { index in
                        let order = state.selected.firstIndex(of: index)
                        DemoTile(index: index)
                            .frame(width: side, height: side)
                            .overlay(alignment: .bottomTrailing) { badge(order) }
                            .scaleEffect(order == nil ? 1 : 0.94)
                            .animation(.spring(duration: 0.25), value: order)
                            .position(center(of: index, side: side, origin: origin))
                    }
                    if state.visible {
                        Finger(pressed: state.pressed)
                            .position(state.position(side: side, origin: origin, demo: self))
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 8)
    }

    private func badge(_ order: Int?) -> some View {
        ZStack {
            Circle().fill(order == nil ? Color.black.opacity(0.25) : Color.accentColor)
            Circle().strokeBorder(.white, lineWidth: 1.5)
            if let order { Text(verbatim: "\(order + 1)").font(.caption2.bold()).foregroundStyle(.white) }
        }
        .frame(width: 22, height: 22)
        .padding(5)
    }

    fileprivate func center(of index: Int, side: CGFloat, origin: CGPoint) -> CGPoint {
        let col = index % columns, row = index / columns
        return CGPoint(x: origin.x + CGFloat(col) * (side + spacing) + side / 2,
                       y: origin.y + CGFloat(row) * (side + spacing) + side / 2)
    }

    private struct FingerState {
        var visible: Bool
        var pressed: Bool
        /// 路径上的位置（0…path.count-1，可为小数）
        var progress: Double
        var selected: [Int]

        func position(side: CGFloat, origin: CGPoint, demo: SwipeSelectDemo) -> CGPoint {
            let i = min(Int(progress), demo.path.count - 1)
            let j = min(i + 1, demo.path.count - 1)
            let f = progress - Double(i)
            let a = demo.center(of: demo.path[i], side: side, origin: origin)
            let b = demo.center(of: demo.path[j], side: side, origin: origin)
            return CGPoint(x: a.x + (b.x - a.x) * f + 10, y: a.y + (b.y - a.y) * f + 14)
        }
    }

    /// 0–0.5s 出现；0.5–3.1s 沿路径滑动；3.1–3.7s 停留；之后淡出重来。
    private func fingerState(at t: Double) -> FingerState {
        let moveStart = 0.5, moveEnd = 3.1
        let steps = Double(path.count - 1)
        let progress: Double
        switch t {
        case ..<moveStart: progress = 0
        case ..<moveEnd:
            let x = (t - moveStart) / (moveEnd - moveStart)
            progress = (x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2) * steps
        default: progress = steps
        }
        let touching = t >= moveStart - 0.1 && t < 3.7
        let selectedCount = touching ? Int(progress.rounded(.down)) + 1 : (t >= 3.7 ? 0 : 0)
        return FingerState(visible: t < 3.9, pressed: touching, progress: progress,
                           selected: Array(path.prefix(selectedCount)))
    }
}

/// 长按预览：手指按住格子，出现震动示意，随后弹出放大预览和菜单。
struct LongPressDemo: View {
    private let cycle = 4.0
    private let target = 5

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
            GeometryReader { proxy in
                let columns = 4, rows = 3, spacing: CGFloat = 3
                let side = min((proxy.size.width - spacing * 3) / 4, (proxy.size.height - spacing * 2) / 3)
                let gridWidth = side * 4 + spacing * 3, gridHeight = side * 3 + spacing * 2
                let origin = CGPoint(x: (proxy.size.width - gridWidth) / 2, y: (proxy.size.height - gridHeight) / 2)
                let tileCenter = CGPoint(x: origin.x + CGFloat(target % columns) * (side + spacing) + side / 2,
                                         y: origin.y + CGFloat(target / columns) * (side + spacing) + side / 2)
                // 阶段：0–0.7 移入；0.7–1.5 按住（收缩 + 进度环）；1.5 震动；1.6–3.4 预览；3.4–4 收回
                let pressing = t >= 0.7 && t < 1.6
                let holdProgress = min(max((t - 0.7) / 0.8, 0), 1)
                let previewShown = t >= 1.6 && t < 3.4
                let buzz = t >= 1.5 && t < 1.8

                ZStack {
                    ForEach(0..<(columns * rows), id: \.self) { index in
                        DemoTile(index: index)
                            .frame(width: side, height: side)
                            .scaleEffect(index == target && pressing ? 1 - 0.08 * holdProgress : 1)
                            .position(x: origin.x + CGFloat(index % columns) * (side + spacing) + side / 2,
                                      y: origin.y + CGFloat(index / columns) * (side + spacing) + side / 2)
                    }
                    .blur(radius: previewShown ? 6 : 0)
                    .animation(.easeInOut(duration: 0.25), value: previewShown)

                    if pressing {
                        Circle()
                            .trim(from: 0, to: holdProgress)
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 50, height: 50)
                            .position(tileCenter)
                    }

                    if previewShown {
                        VStack(spacing: 8) {
                            DemoTile(index: target)
                                .frame(width: proxy.size.width * 0.62, height: proxy.size.width * 0.62 * 0.75)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(alignment: .topLeading) {
                                    Image(systemName: "livephoto").foregroundStyle(.white).padding(8)
                                }
                            VStack(alignment: .leading, spacing: 0) {
                                menuRow("slider.horizontal.3", "Edit")
                                Divider()
                                menuRow("checkmark.circle", "Select")
                            }
                            .frame(width: proxy.size.width * 0.45)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    }

                    if t < 1.7 {
                        Finger(pressed: pressing)
                            .position(x: tileCenter.x + 12 + (t < 0.7 ? CGFloat(0.7 - t) * 120 : 0),
                                      y: tileCenter.y + 16 + (t < 0.7 ? CGFloat(0.7 - t) * 80 : 0))
                    }

                    if buzz {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                            .font(.title2)
                            .foregroundStyle(.tint)
                            .padding(8)
                            .background(.regularMaterial, in: Circle())
                            .position(x: tileCenter.x, y: max(tileCenter.y - side * 0.9, 24))
                            .offset(x: sin(t * 80) * 3)
                    }
                }
                .animation(.spring(duration: 0.35), value: previewShown)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 8)
    }

    private func menuRow(_ icon: String, _ title: LocalizedStringKey) -> some View {
        Label(title, systemImage: icon)
            .font(.footnote)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
