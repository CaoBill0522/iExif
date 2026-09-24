import Foundation

enum SaveMode: String, CaseIterable, Identifiable {
    /// 另存为新照片，保留原图
    case saveAsNew
    /// 另存为新照片并删除原图
    case replaceOriginal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .saveAsNew: String(localized: "Save as New Photo")
        case .replaceOriginal: String(localized: "Save & Delete Original")
        }
    }

    var detail: String {
        switch self {
        case .saveAsNew: String(localized: "The original photo is kept.")
        case .replaceOriginal: String(localized: "iOS asks you to confirm the deletion. Deleted photos stay in Recently Deleted for 30 days.")
        }
    }
}

/// 输出格式策略。
enum OutputFormatMode: String, CaseIterable, Identifiable {
    /// 跟随机型默认：能拍 HEIC 的机型输出 HEIC，否则 JPEG
    case followDevice
    /// 保持原格式，只在该机型不可能拍出这种格式时转换
    case keepOriginal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .followDevice: String(localized: "Match Device Default")
        case .keepOriginal: String(localized: "Keep Original Format")
        }
    }
}

enum SettingsKey {
    static let saveMode = "saveMode"
    static let stripMakerNote = "stripMakerNote"
    static let outputFormat = "outputFormat"
    static let matchResolution = "matchResolution"
}

extension UserDefaults {
    var defaultSaveMode: SaveMode {
        string(forKey: SettingsKey.saveMode).flatMap(SaveMode.init) ?? .saveAsNew
    }

    var stripMakerNoteByDefault: Bool {
        bool(forKey: SettingsKey.stripMakerNote)
    }

    var outputFormatMode: OutputFormatMode {
        string(forKey: SettingsKey.outputFormat).flatMap(OutputFormatMode.init) ?? .followDevice
    }

    var matchResolutionByDefault: Bool {
        bool(forKey: SettingsKey.matchResolution)
    }
}
