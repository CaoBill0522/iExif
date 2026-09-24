import Foundation

/// 可编辑的元数据字段。批量修改和模板按这个粒度勾选。
enum MetadataField: String, Codable, CaseIterable, Identifiable {
    /// Make、Model、Software
    case device
    /// LensMake、LensModel、FNumber、FocalLength、FocalLengthIn35mmFilm
    case lens
    case exposureTime
    case iso
    case exposureBias
    case meteringMode
    case flash
    case whiteBalance
    case dateTime
    case location
    case artist
    case copyright
    case imageDescription

    var id: String { rawValue }

    var title: String {
        switch self {
        case .device: String(localized: "Device")
        case .lens: String(localized: "Lens")
        case .exposureTime: String(localized: "Shutter Speed")
        case .iso: String(localized: "ISO")
        case .exposureBias: String(localized: "Exposure Compensation")
        case .meteringMode: String(localized: "Metering Mode")
        case .flash: String(localized: "Flash")
        case .whiteBalance: String(localized: "White Balance")
        case .dateTime: String(localized: "Date Taken")
        case .location: String(localized: "Location")
        case .artist: String(localized: "Artist")
        case .copyright: String(localized: "Copyright")
        case .imageDescription: String(localized: "Description")
        }
    }
}

/// 位置，坐标一律是 WGS-84（即 EXIF 中存储的坐标系）。
struct GeoLocation: Codable, Hashable {
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    /// 拍摄朝向，0–360°，相对正北。
    var direction: Double?
}

struct PhotoMetadata: Codable, Hashable {
    // 设备
    var make: String?
    var model: String?
    var software: String?
    // 镜头
    var lensMake: String?
    var lensModel: String?
    var fNumber: Double?
    var focalLength: Double?
    var focalLength35mm: Int?
    // 拍摄参数
    var exposureTime: Double?
    var iso: Int?
    var exposureBias: Double?
    var meteringMode: Int?
    var flash: Int?
    var whiteBalance: Int?
    // 时间
    var dateTaken: Date?
    /// 相对 GMT 的秒数，对应 OffsetTimeOriginal。
    var timeZoneOffset: Int?
    // 位置
    var location: GeoLocation?
    // 版权
    var artist: String?
    var copyright: String?
    var imageDescription: String?

    /// 用 `source` 中指定字段的值覆盖自身。
    mutating func apply(_ fields: Set<MetadataField>, from source: PhotoMetadata) {
        for field in fields {
            switch field {
            case .device:
                make = source.make
                model = source.model
                software = source.software
            case .lens:
                lensMake = source.lensMake
                lensModel = source.lensModel
                fNumber = source.fNumber
                focalLength = source.focalLength
                focalLength35mm = source.focalLength35mm
            case .exposureTime: exposureTime = source.exposureTime
            case .iso: iso = source.iso
            case .exposureBias: exposureBias = source.exposureBias
            case .meteringMode: meteringMode = source.meteringMode
            case .flash: flash = source.flash
            case .whiteBalance: whiteBalance = source.whiteBalance
            case .dateTime:
                dateTaken = source.dateTaken
                timeZoneOffset = source.timeZoneOffset
            case .location: location = source.location
            case .artist: artist = source.artist
            case .copyright: copyright = source.copyright
            case .imageDescription: imageDescription = source.imageDescription
            }
        }
    }

    /// 与 `other` 不同的字段。
    func changedFields(comparedTo other: PhotoMetadata) -> Set<MetadataField> {
        Set(MetadataField.allCases.filter { field in
            var probe = other
            probe.apply([field], from: self)
            return probe != other
        })
    }

    mutating func applyPreset(device: DevicePreset, lens: LensPreset?) {
        make = device.make
        model = device.model
        if let software = device.software { self.software = software }
        guard let lens else { return }
        lensMake = device.make
        lensModel = lens.lensModel
        fNumber = lens.fNumber
        focalLength = lens.focalLength
        focalLength35mm = lens.focalLength35mm
    }

    var timeZone: TimeZone {
        timeZoneOffset.flatMap { TimeZone(secondsFromGMT: $0) } ?? .current
    }
}

// MARK: - 枚举值

enum MeteringMode: Int, CaseIterable, Identifiable {
    case unknown = 0, average = 1, centerWeighted = 2, spot = 3, multiSpot = 4, pattern = 5, partial = 6

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .unknown: String(localized: "Unknown")
        case .average: String(localized: "Average")
        case .centerWeighted: String(localized: "Center-weighted")
        case .spot: String(localized: "Spot")
        case .multiSpot: String(localized: "Multi-spot")
        case .pattern: String(localized: "Pattern (Matrix)")
        case .partial: String(localized: "Partial")
        }
    }
}

enum FlashMode: Int, CaseIterable, Identifiable {
    case none = 0
    case fired = 1
    case onFired = 9
    case offDidNotFire = 16
    case autoDidNotFire = 24
    case autoFired = 25

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .none: String(localized: "No Flash")
        case .fired: String(localized: "Fired")
        case .onFired: String(localized: "On, Fired")
        case .offDidNotFire: String(localized: "Off, Did Not Fire")
        case .autoDidNotFire: String(localized: "Auto, Did Not Fire")
        case .autoFired: String(localized: "Auto, Fired")
        }
    }
}

enum WhiteBalanceMode: Int, CaseIterable, Identifiable {
    case auto = 0, manual = 1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .auto: String(localized: "Auto")
        case .manual: String(localized: "Manual")
        }
    }
}

// MARK: - 格式化

enum ExposureFormat {
    /// 0.004 → "1/250"，2 → "2"
    static func string(_ seconds: Double) -> String {
        if seconds < 1, seconds > 0 {
            return "1/\(Int((1 / seconds).rounded()))"
        }
        return seconds.formatted(.number.precision(.fractionLength(0...1)))
    }

    /// 接受 "1/250"、"0.004"、"2" 等形式。
    static func parse(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: "/")
        if parts.count == 2, let n = Double(parts[0]), let d = Double(parts[1]), d != 0, n > 0 {
            return n / d
        }
        if let value = Double(trimmed), value > 0 { return value }
        return nil
    }
}

enum TimeZoneFormat {
    /// 28800 → "+08:00"
    static func string(_ seconds: Int) -> String {
        let sign = seconds < 0 ? "-" : "+"
        let minutes = abs(seconds) / 60
        return String(format: "%@%02d:%02d", sign, minutes / 60, minutes % 60)
    }

    static func parse(_ text: String) -> Int? {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard t.count == 6, let sign = t.first, sign == "+" || sign == "-" else { return nil }
        let parts = t.dropFirst().split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return (sign == "-" ? -1 : 1) * (h * 3600 + m * 60)
    }

    /// 常用时区偏移，-12:00 到 +14:00，含半小时和 45 分钟时区。
    static let common: [Int] = {
        var values = Array(stride(from: -12 * 3600, through: 14 * 3600, by: 3600))
        values += [-9 * 3600 - 1800, -3 * 3600 - 1800, 3 * 3600 + 1800, 4 * 3600 + 1800, 5 * 3600 + 1800,
                   5 * 3600 + 2700, 6 * 3600 + 1800, 8 * 3600 + 2700, 9 * 3600 + 1800, 10 * 3600 + 1800, 12 * 3600 + 2700]
        return values.sorted()
    }()
}
