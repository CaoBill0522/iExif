import Foundation
import ImageIO
import UniformTypeIdentifiers

enum MetadataError: LocalizedError {
    case unreadableImage
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .unreadableImage: String(localized: "This file isn't a supported image.")
        case .writeFailed: String(localized: "Couldn't write the metadata.")
        }
    }
}

/// 基于 ImageIO 的元数据读写。
///
/// JPEG / HEIC 使用 `CGImageDestinationCopyImageSource` 只替换元数据块，图像数据不重新编码；
/// PNG 本身无损，走属性字典重写。
enum MetadataService {
    struct ReadResult {
        var typeIdentifier: String
        var properties: [String: Any]
        var metadata: PhotoMetadata
        var pixelWidth: Int?
        var pixelHeight: Int?
    }

    static func read(_ data: Data) throws -> ReadResult {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        else { throw MetadataError.unreadableImage }
        return ReadResult(
            typeIdentifier: type as String,
            properties: properties,
            metadata: parse(properties),
            pixelWidth: properties[kCGImagePropertyPixelWidth as String] as? Int,
            pixelHeight: properties[kCGImagePropertyPixelHeight as String] as? Int
        )
    }

    /// 把 `values` 中 `fields` 指定的字段写入图片，返回新文件数据。字段值为 nil 表示删除该标签。
    static func write(
        _ data: Data,
        fields: Set<MetadataField>,
        values: PhotoMetadata,
        original: PhotoMetadata,
        stripMakerNote: Bool
    ) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source)
        else { throw MetadataError.unreadableImage }

        let removesLocation = fields.contains(.location) && values.location == nil
        var final = original
        final.apply(fields, from: values)
        let hasLocation = final.location != nil

        if UTType(type as String)?.conforms(to: .png) != true,
           let output = try? copyWithXMP(source: source, type: type, fields: fields, values: values,
                                         hasLocation: hasLocation, removesLocation: removesLocation,
                                         stripMakerNote: stripMakerNote) {
            return output
        }
        return try rewriteWithProperties(source: source, type: type, fields: fields, values: values,
                                         hasLocation: hasLocation, removesLocation: removesLocation,
                                         stripMakerNote: stripMakerNote)
    }

    // MARK: - 写入：无损复制

    private static func copyWithXMP(
        source: CGImageSource, type: CFString, fields: Set<MetadataField>, values: PhotoMetadata,
        hasLocation: Bool, removesLocation: Bool, stripMakerNote: Bool
    ) throws -> Data {
        guard let base = CGImageSourceCopyMetadataAtIndex(source, 0, nil) else { throw MetadataError.writeFailed }

        let metadata: CGMutableImageMetadata
        if stripMakerNote {
            // MakerNote 不在 XMP 树里：新建空元数据再复制全部标签，MakerNote 自然被丢弃。
            metadata = CGImageMetadataCreateMutable()
            CGImageMetadataEnumerateTagsUsingBlock(base, nil, nil) { path, tag in
                if let ns = CGImageMetadataTagCopyNamespace(tag), let prefix = CGImageMetadataTagCopyPrefix(tag) {
                    CGImageMetadataRegisterNamespaceForPrefix(metadata, ns, prefix, nil)
                }
                CGImageMetadataSetTagWithPath(metadata, nil, path, tag)
                return true
            }
        } else {
            guard let copy = CGImageMetadataCreateMutableCopy(base) else { throw MetadataError.writeFailed }
            metadata = copy
        }

        var sink = XMPSink(metadata: metadata)
        apply(fields: fields, values: values, hasLocation: hasLocation, to: &sink)

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type, 1, nil) else { throw MetadataError.writeFailed }
        var options: [CFString: Any] = [
            kCGImageDestinationMetadata: metadata,
            kCGImageDestinationMergeMetadata: false,
        ]
        if removesLocation { options[kCGImageMetadataShouldExcludeGPS] = true }
        guard CGImageDestinationCopyImageSource(destination, source, options as CFDictionary, nil) else {
            throw MetadataError.writeFailed
        }
        return output as Data
    }

    // MARK: - 写入：属性字典（PNG 及兜底）

    private static func rewriteWithProperties(
        source: CGImageSource, type: CFString, fields: Set<MetadataField>, values: PhotoMetadata,
        hasLocation: Bool, removesLocation: Bool, stripMakerNote: Bool
    ) throws -> Data {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        var sink = DictionarySink(properties: properties)
        apply(fields: fields, values: values, hasLocation: hasLocation, to: &sink)
        var output = sink.properties
        if removesLocation { output[kCGImagePropertyGPSDictionary as String] = kCFNull }
        if stripMakerNote { output[kCGImagePropertyMakerAppleDictionary as String] = kCFNull }
        output[kCGImageDestinationLossyCompressionQuality as String] = 1.0

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type, 1, nil) else { throw MetadataError.writeFailed }
        CGImageDestinationAddImageFromSource(destination, source, 0, output as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw MetadataError.writeFailed }
        return data as Data
    }

    // MARK: - 字段 → 标签

    private static func apply<S: MetadataSink>(fields: Set<MetadataField>, values v: PhotoMetadata, hasLocation: Bool, to s: inout S) {
        let tiff = kCGImagePropertyTIFFDictionary, exif = kCGImagePropertyExifDictionary, gps = kCGImagePropertyGPSDictionary

        for field in fields {
            switch field {
            case .device:
                s.set(tiff, kCGImagePropertyTIFFMake, v.make.map(MetadataValue.string))
                s.set(tiff, kCGImagePropertyTIFFModel, v.model.map(MetadataValue.string))
                s.set(tiff, kCGImagePropertyTIFFSoftware, v.software.map(MetadataValue.string))
            case .lens:
                s.set(exif, kCGImagePropertyExifLensMake, v.lensMake.map(MetadataValue.string))
                s.set(exif, kCGImagePropertyExifLensModel, v.lensModel.map(MetadataValue.string))
                s.set(exif, kCGImagePropertyExifFNumber, v.fNumber.map(MetadataValue.rational))
                s.set(exif, kCGImagePropertyExifFocalLength, v.focalLength.map(MetadataValue.rational))
                s.set(exif, kCGImagePropertyExifFocalLenIn35mmFilm, v.focalLength35mm.map(MetadataValue.int))
            case .exposureTime:
                s.set(exif, kCGImagePropertyExifExposureTime, v.exposureTime.map(MetadataValue.rational))
            case .iso:
                s.set(exif, kCGImagePropertyExifISOSpeedRatings, v.iso.map { .intArray([$0]) })
            case .exposureBias:
                s.set(exif, kCGImagePropertyExifExposureBiasValue, v.exposureBias.map(MetadataValue.rational))
            case .meteringMode:
                s.set(exif, kCGImagePropertyExifMeteringMode, v.meteringMode.map(MetadataValue.int))
            case .flash:
                s.set(exif, kCGImagePropertyExifFlash, v.flash.map(MetadataValue.int))
            case .whiteBalance:
                s.set(exif, kCGImagePropertyExifWhiteBalance, v.whiteBalance.map(MetadataValue.int))
            case .dateTime:
                let tz = v.timeZone
                let local = v.dateTaken.map { MetadataValue.string(DateFormat.exif(from: $0, in: tz)) }
                let offset = v.dateTaken.map { MetadataValue.string(TimeZoneFormat.string(tz.secondsFromGMT(for: $0))) }
                s.set(exif, kCGImagePropertyExifDateTimeOriginal, local)
                s.set(exif, kCGImagePropertyExifDateTimeDigitized, local)
                s.set(tiff, kCGImagePropertyTIFFDateTime, local)
                s.set(exif, kCGImagePropertyExifOffsetTimeOriginal, offset)
                s.set(exif, kCGImagePropertyExifOffsetTimeDigitized, offset)
                s.set(exif, kCGImagePropertyExifOffsetTime, offset)
                if hasLocation, let date = v.dateTaken {
                    s.set(gps, kCGImagePropertyGPSDateStamp, .string(DateFormat.gpsDate(from: date)))
                    s.set(gps, kCGImagePropertyGPSTimeStamp, .string(DateFormat.gpsTime(from: date)))
                }
            case .location:
                guard let loc = v.location else { continue } // 删除位置由 excludeGPS 处理
                s.set(gps, kCGImagePropertyGPSLatitude, .double(abs(loc.latitude)))
                s.set(gps, kCGImagePropertyGPSLatitudeRef, .string(loc.latitude >= 0 ? "N" : "S"))
                s.set(gps, kCGImagePropertyGPSLongitude, .double(abs(loc.longitude)))
                s.set(gps, kCGImagePropertyGPSLongitudeRef, .string(loc.longitude >= 0 ? "E" : "W"))
                s.set(gps, kCGImagePropertyGPSAltitude, loc.altitude.map { .rational(abs($0)) })
                s.set(gps, kCGImagePropertyGPSAltitudeRef, loc.altitude.map { .int($0 < 0 ? 1 : 0) })
                s.set(gps, kCGImagePropertyGPSImgDirection, loc.direction.map(MetadataValue.rational))
                s.set(gps, kCGImagePropertyGPSImgDirectionRef, loc.direction.map { _ in .string("T") })
                // 旧的定位精度、速度等与新位置无关，一并清掉。
                for key in [kCGImagePropertyGPSHPositioningError, kCGImagePropertyGPSSpeed, kCGImagePropertyGPSSpeedRef,
                            kCGImagePropertyGPSDestBearing, kCGImagePropertyGPSDestBearingRef] {
                    s.set(gps, key, nil)
                }
            case .artist:
                s.set(tiff, kCGImagePropertyTIFFArtist, v.artist.map(MetadataValue.string))
            case .copyright:
                s.set(tiff, kCGImagePropertyTIFFCopyright, v.copyright.map(MetadataValue.string))
            case .imageDescription:
                s.set(tiff, kCGImagePropertyTIFFImageDescription, v.imageDescription.map(MetadataValue.string))
            }
        }
    }

    // MARK: - 读取

    static func parse(_ p: [String: Any]) -> PhotoMetadata {
        let tiff = p[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        let exif = p[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        let gps = p[kCGImagePropertyGPSDictionary as String] as? [String: Any] ?? [:]
        func str(_ d: [String: Any], _ k: CFString) -> String? {
            (d[k as String] as? String).flatMap { $0.isEmpty ? nil : $0 }
        }
        func num(_ d: [String: Any], _ k: CFString) -> Double? { (d[k as String] as? NSNumber)?.doubleValue }

        var m = PhotoMetadata()
        m.make = str(tiff, kCGImagePropertyTIFFMake)
        m.model = str(tiff, kCGImagePropertyTIFFModel)
        m.software = str(tiff, kCGImagePropertyTIFFSoftware)
        m.lensMake = str(exif, kCGImagePropertyExifLensMake)
        m.lensModel = str(exif, kCGImagePropertyExifLensModel)
        m.fNumber = num(exif, kCGImagePropertyExifFNumber)
        m.focalLength = num(exif, kCGImagePropertyExifFocalLength)
        m.focalLength35mm = num(exif, kCGImagePropertyExifFocalLenIn35mmFilm).map { Int($0) }
        m.exposureTime = num(exif, kCGImagePropertyExifExposureTime)
        m.iso = (exif[kCGImagePropertyExifISOSpeedRatings as String] as? [NSNumber])?.first?.intValue
        m.exposureBias = num(exif, kCGImagePropertyExifExposureBiasValue)
        m.meteringMode = num(exif, kCGImagePropertyExifMeteringMode).map { Int($0) }
        m.flash = num(exif, kCGImagePropertyExifFlash).map { Int($0) }
        m.whiteBalance = num(exif, kCGImagePropertyExifWhiteBalance).map { Int($0) }

        let offsetText = str(exif, kCGImagePropertyExifOffsetTimeOriginal) ?? str(exif, kCGImagePropertyExifOffsetTime)
        m.timeZoneOffset = offsetText.flatMap(TimeZoneFormat.parse)
        if let text = str(exif, kCGImagePropertyExifDateTimeOriginal) ?? str(tiff, kCGImagePropertyTIFFDateTime) {
            m.dateTaken = DateFormat.date(fromEXIF: text, in: m.timeZone)
        }

        if let lat = num(gps, kCGImagePropertyGPSLatitude), let lon = num(gps, kCGImagePropertyGPSLongitude) {
            let latSign: Double = str(gps, kCGImagePropertyGPSLatitudeRef) == "S" ? -1 : 1
            let lonSign: Double = str(gps, kCGImagePropertyGPSLongitudeRef) == "W" ? -1 : 1
            var altitude = num(gps, kCGImagePropertyGPSAltitude)
            if num(gps, kCGImagePropertyGPSAltitudeRef) == 1 { altitude = altitude.map { -$0 } }
            m.location = GeoLocation(latitude: lat * latSign, longitude: lon * lonSign,
                                     altitude: altitude, direction: num(gps, kCGImagePropertyGPSImgDirection))
        }

        m.artist = str(tiff, kCGImagePropertyTIFFArtist)
        m.copyright = str(tiff, kCGImagePropertyTIFFCopyright)
        m.imageDescription = str(tiff, kCGImagePropertyTIFFImageDescription)
        return m
    }
}

// MARK: - 写入目标

enum MetadataValue {
    case string(String)
    case int(Int)
    case intArray([Int])
    case double(Double)
    /// EXIF RATIONAL 类型，写入 XMP 时必须用 "n/d" 字符串，否则会被截断成整数。
    case rational(Double)
}

private protocol MetadataSink {
    /// value 为 nil 表示删除。
    mutating func set(_ dictionary: CFString, _ key: CFString, _ value: MetadataValue?)
}

private struct XMPSink: MetadataSink {
    let metadata: CGMutableImageMetadata

    private static let exifNS = "http://ns.adobe.com/exif/1.0/" as CFString
    private static let exifEXNS = "http://cipa.jp/exif/1.0/" as CFString

    func set(_ dictionary: CFString, _ key: CFString, _ value: MetadataValue?) {
        if key == kCGImagePropertyExifISOSpeedRatings {
            setISO(value)
            return
        }
        if key == kCGImagePropertyExifFlash, case .int(let flash) = value {
            setFlash(flash)
            return
        }
        guard let value else {
            remove(dictionary, key)
            return
        }
        let object: CFTypeRef = switch value {
        case .string(let s): s as CFString
        case .int(let i): NSNumber(value: i)
        case .intArray(let a): a.map { NSNumber(value: $0) } as CFArray
        case .double(let d): NSNumber(value: d)
        case .rational(let d): Rational.string(d) as CFString
        }
        CGImageMetadataSetValueMatchingImageProperty(metadata, dictionary, key, object)
    }

    private func remove(_ dictionary: CFString, _ key: CFString) {
        if let tag = CGImageMetadataCopyTagMatchingImageProperty(metadata, dictionary, key),
           let prefix = CGImageMetadataTagCopyPrefix(tag), let name = CGImageMetadataTagCopyName(tag) {
            CGImageMetadataRemoveTagWithPath(metadata, nil, "\(prefix):\(name)" as CFString)
        }
    }

    /// ISO 在 XMP 中有两处：exif:ISOSpeedRatings（有序数组）和 exifEX:PhotographicSensitivity，
    /// 读取时后者优先，必须同时写。
    private func setISO(_ value: MetadataValue?) {
        CGImageMetadataRemoveTagWithPath(metadata, nil, "exif:ISOSpeedRatings" as CFString)
        CGImageMetadataRemoveTagWithPath(metadata, nil, "exifEX:PhotographicSensitivity" as CFString)
        guard case .intArray(let values) = value, let iso = values.first else { return }
        CGImageMetadataRegisterNamespaceForPrefix(metadata, Self.exifEXNS, "exifEX" as CFString, nil)
        if let tag = CGImageMetadataTagCreate(Self.exifNS, "exif" as CFString, "ISOSpeedRatings" as CFString,
                                              .arrayOrdered, ["\(iso)"] as CFArray) {
            CGImageMetadataSetTagWithPath(metadata, nil, "exif:ISOSpeedRatings" as CFString, tag)
        }
        if let tag = CGImageMetadataTagCreate(Self.exifEXNS, "exifEX" as CFString, "PhotographicSensitivity" as CFString,
                                              .string, "\(iso)" as CFString) {
            CGImageMetadataSetTagWithPath(metadata, nil, "exifEX:PhotographicSensitivity" as CFString, tag)
        }
    }

    /// XMP 中 exif:Flash 是结构体，需要按 EXIF Flash 位域拆开。
    private func setFlash(_ flash: Int) {
        CGImageMetadataRemoveTagWithPath(metadata, nil, "exif:Flash" as CFString)
        let fields: [String: String] = [
            "Fired": flash & 0x1 != 0 ? "True" : "False",
            "Return": "\((flash >> 1) & 0x3)",
            "Mode": "\((flash >> 3) & 0x3)",
            "Function": flash & 0x20 != 0 ? "True" : "False",
            "RedEyeMode": flash & 0x40 != 0 ? "True" : "False",
        ]
        var subtags: [String: CGImageMetadataTag] = [:]
        for (name, value) in fields {
            subtags[name] = CGImageMetadataTagCreate(Self.exifNS, "exif" as CFString, name as CFString, .string, value as CFString)
        }
        if let tag = CGImageMetadataTagCreate(Self.exifNS, "exif" as CFString, "Flash" as CFString, .structure, subtags as CFDictionary) {
            CGImageMetadataSetTagWithPath(metadata, nil, "exif:Flash" as CFString, tag)
        }
    }
}

private struct DictionarySink: MetadataSink {
    var properties: [String: Any]

    mutating func set(_ dictionary: CFString, _ key: CFString, _ value: MetadataValue?) {
        var dict = properties[dictionary as String] as? [String: Any] ?? [:]
        dict[key as String] = switch value {
        case nil: kCFNull as Any
        case .string(let s): s
        case .int(let i): i
        case .intArray(let a): a
        case .double(let d), .rational(let d): d
        }
        properties[dictionary as String] = dict
    }
}

enum Rational {
    /// 1.78 → "178/100"，0.004 → "1/250"
    static func string(_ value: Double) -> String {
        if value > 0, value < 1 {
            let inverse = 1 / value
            if abs(inverse - inverse.rounded()) < 1e-6 { return "1/\(Int(inverse.rounded()))" }
        }
        // 优先用能精确表示该值的分母（苹果常用 2 的幂，如 2.71484375 = 695/256）
        let denominator = [1000, 10_000, 1024, 65_536].first {
            abs(value * Double($0) - (value * Double($0)).rounded()) < 1e-9
        } ?? 10_000
        let numerator = Int((value * Double(denominator)).rounded())
        let g = gcd(abs(numerator), denominator)
        return "\(numerator / g)/\(denominator / g)"
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? max(a, 1) : gcd(b, a % b) }
}

enum DateFormat {
    private static func formatter(_ format: String, _ tz: TimeZone) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = tz
        f.dateFormat = format
        return f
    }

    static func exif(from date: Date, in tz: TimeZone) -> String {
        formatter("yyyy:MM:dd HH:mm:ss", tz).string(from: date)
    }

    static func date(fromEXIF text: String, in tz: TimeZone) -> Date? {
        formatter("yyyy:MM:dd HH:mm:ss", tz).date(from: String(text.prefix(19)))
    }

    static func gpsDate(from date: Date) -> String {
        formatter("yyyy:MM:dd", TimeZone(identifier: "UTC")!).string(from: date)
    }

    static func gpsTime(from date: Date) -> String {
        formatter("HH:mm:ss", TimeZone(identifier: "UTC")!).string(from: date)
    }
}
