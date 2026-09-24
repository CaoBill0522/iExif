import SwiftUI
import UniformTypeIdentifiers

struct AlertInfo: Identifiable {
    let id = UUID()
    var title: String
    var message: String
    var dismissesEditor = false

    init(title: String, message: String, dismissesEditor: Bool = false) {
        self.title = title
        self.message = message
        self.dismissesEditor = dismissesEditor
    }

    init(error: Error) {
        title = String(localized: "Something Went Wrong")
        message = error.localizedDescription
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct ImageFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.image] }

    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum TemporaryFile {
    /// 写入临时目录并保留原文件名，便于分享后文件名不变。
    static func write(_ data: Data, filename: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(filename)
        try data.write(to: url)
        return url
    }
}

/// 时间整体平移量编辑（天 / 小时 / 分钟）。
struct TimeShiftRows: View {
    @Binding var seconds: Int

    var body: some View {
        stepper("Days", unit: 86_400, range: -3650...3650)
        stepper("Hours", unit: 3_600, range: -23...23)
        stepper("Minutes", unit: 60, range: -59...59)
        LabeledContent("Total Shift", value: Self.describe(seconds))
    }

    private func stepper(_ title: LocalizedStringKey, unit: Int, range: ClosedRange<Int>) -> some View {
        let binding = Binding<Int>(
            get: { component(unit) },
            set: { seconds += ($0 - component(unit)) * unit }
        )
        return Stepper(value: binding, in: range) {
            LabeledContent(title, value: "\(binding.wrappedValue)")
        }
    }

    /// 按符号拆分：先天、再小时、再分钟，各分量与总量同号。
    private func component(_ unit: Int) -> Int {
        let sign = seconds < 0 ? -1 : 1
        let total = abs(seconds)
        switch unit {
        case 86_400: return sign * (total / 86_400)
        case 3_600: return sign * (total % 86_400 / 3_600)
        default: return sign * (total % 3_600 / 60)
        }
    }

    static func describe(_ seconds: Int) -> String {
        guard seconds != 0 else { return String(localized: "None") }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .short
        let text = formatter.string(from: TimeInterval(abs(seconds))) ?? ""
        return (seconds > 0 ? "+" : "−") + text
    }
}

/// 保存选项下方关于格式转换、分辨率和实况照片的说明。
struct OutputNotes: View {
    let plan: OutputPlan?
    let isLivePhoto: Bool
    var keepsMakerNote = false

    var body: some View {
        if let plan, plan.reencodes {
            Text("The image will be re-encoded at \(Int(ImageTranscoder.quality * 100))% quality to change its format or size.")
            if plan.crops {
                Text("A little of the edges will be cropped to match the camera's aspect ratio.")
            }
            if plan.upscales {
                Text("The photo will be enlarged and may look blurry.")
                    .foregroundStyle(.orange)
            }
        }
        if isLivePhoto {
            Text("Live Photo: the video is saved too, and its date, location and device are updated to match.")
        }
        if keepsMakerNote {
            Text("Live Photos need the pairing ID stored in MakerNote, so MakerNote is kept for this lossless save.")
                .foregroundStyle(.orange)
        }
    }
}
