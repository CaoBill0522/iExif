import Foundation

/// 内置设备预设库（Resources/Devices.json）。
struct DeviceCatalog: Codable {
    var version: Int
    var devices: [DevicePreset]
}

struct DevicePreset: Codable, Identifiable, Hashable {
    enum Family: String, Codable, CaseIterable {
        case iPhone, iPad
    }

    var id: String
    var family: Family
    /// 写入 EXIF 的 Model 字段。
    var model: String
    /// 显示名称；部分机型的 EXIF 型号不区分代数（如 iPad 3 / iPad 4 都写 "iPad"），此时单独给出。
    var name: String?
    var make: String
    var year: Int
    /// 该机型出厂时的 iOS / iPadOS 版本，用于填充 Software。
    var software: String?
    /// 能否拍 HEIC（A10 及以后）；决定默认输出格式。
    var heif: Bool?
    var lenses: [LensPreset]

    var displayName: String { name ?? model }
}

struct LensPreset: Codable, Identifiable, Hashable {
    enum Position: String, Codable {
        case back, front
    }

    enum Kind: String, Codable {
        case ultraWide, wide, telephoto, front
    }

    var id: String
    var position: Position
    var kind: Kind
    /// 真机写入的 LensModel 字符串。
    var lensModel: String
    var focalLength: Double
    var fNumber: Double
    var focalLength35mm: Int
    /// 没有找到真机 EXIF、按官方规格推算的镜头。
    var estimated: Bool?
    /// 相机默认输出分辨率（4:3 横向）。
    var pixelWidth: Int?
    var pixelHeight: Int?

    var localizedKind: String {
        switch kind {
        case .ultraWide: String(localized: "Ultra Wide")
        case .wide: String(localized: "Main")
        case .telephoto: String(localized: "Telephoto")
        case .front: String(localized: "Front")
        }
    }

    var summary: String {
        "\(focalLength35mm)mm  f/\(fNumber.formatted(.number.precision(.fractionLength(0...2))))"
    }
}

@MainActor
final class DeviceCatalogStore {
    static let shared = DeviceCatalogStore()

    let devices: [DevicePreset]

    private init() {
        guard let url = Bundle.main.url(forResource: "Devices", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(DeviceCatalog.self, from: data)
        else {
            assertionFailure("Devices.json missing or invalid")
            devices = []
            return
        }
        devices = catalog.devices.sorted { ($0.year, $0.displayName) > ($1.year, $1.displayName) }
    }

    func devices(in family: DevicePreset.Family) -> [DevicePreset] {
        devices.filter { $0.family == family }
    }

    /// 根据 Model + LensModel 反查预设，用于在编辑界面显示当前匹配的镜头。
    func match(model: String?, lensModel: String?) -> (DevicePreset, LensPreset?)? {
        guard let model, let device = devices.first(where: { $0.model == model }) else { return nil }
        return (device, device.lenses.first { $0.lensModel == lensModel })
    }
}
