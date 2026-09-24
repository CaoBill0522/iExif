import MapKit
import SwiftUI

/// 单个 MetadataField 对应的编辑行，单张编辑和批量编辑共用。
struct FieldRows: View {
    let field: MetadataField
    @Binding var values: PhotoMetadata

    /// 弹窗由外层表单统一弹出（见 `fieldSheets`），挂在表单行上的 sheet 会随行重建而被关闭。
    @Environment(\.fieldSheet) private var sheet

    var body: some View {
        switch field {
        case .device: deviceRows
        case .lens: lensRows
        case .exposureTime: ExposureTimeRow(value: $values.exposureTime)
        case .iso: isoRow
        case .exposureBias: ExposureBiasRow(value: $values.exposureBias)
        case .meteringMode:
            OptionalPicker(title: "Metering Mode", value: $values.meteringMode, options: MeteringMode.allCases) { $0.title }
        case .flash:
            OptionalPicker(title: "Flash", value: $values.flash, options: FlashMode.allCases) { $0.title }
        case .whiteBalance:
            OptionalPicker(title: "White Balance", value: $values.whiteBalance, options: WhiteBalanceMode.allCases) { $0.title }
        case .dateTime: DateTimeRows(values: $values)
        case .location: locationRows
        case .artist: TextRow(title: "Artist", value: $values.artist)
        case .copyright: TextRow(title: "Copyright", value: $values.copyright)
        case .imageDescription: TextRow(title: "Description", value: $values.imageDescription, axis: .vertical)
        }
    }

    // MARK: 设备

    @ViewBuilder
    private var deviceRows: some View {
        Button {
            sheet?.wrappedValue = .devicePicker
        } label: {
            HStack {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Choose from Presets")
                        if let match = DeviceCatalogStore.shared.match(model: values.model, lensModel: values.lensModel) {
                            Text(match.1.map { "\(match.0.displayName) · \($0.localizedKind) \($0.summary)" } ?? match.0.displayName)
                                .font(.caption)
                                .foregroundColor(Color(.secondaryLabel))
                        }
                    }
                } icon: {
                    Image(systemName: "iphone.gen3")
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
        }
        TextRow(title: "Make", value: $values.make)
        TextRow(title: "Model", value: $values.model)
        TextRow(title: "Software", value: $values.software)
    }

    // MARK: 镜头

    @ViewBuilder
    private var lensRows: some View {
        TextRow(title: "Lens Make", value: $values.lensMake)
        TextRow(title: "Lens Model", value: $values.lensModel, axis: .vertical)
        NumberRow(title: "Aperture", value: $values.fNumber, prefix: "f/", maxFractionDigits: 2)
        NumberRow(title: "Focal Length", value: $values.focalLength, unit: "mm", maxFractionDigits: 3)
        IntRow(title: "35mm Equivalent", value: $values.focalLength35mm, unit: "mm")
    }

    // MARK: ISO

    private static let isoValues = [25, 32, 50, 64, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640, 800, 1000, 1250, 1600, 2000, 2500, 3200, 5000, 6400, 12800]

    private var isoRow: some View {
        HStack {
            IntRow(title: "ISO", value: $values.iso)
            Menu {
                ForEach(Self.isoValues, id: \.self) { iso in
                    Button("ISO \(iso)") { values.iso = iso }
                }
            } label: {
                Image(systemName: "list.bullet.circle")
            }
        }
    }

    // MARK: 位置

    @ViewBuilder
    private var locationRows: some View {
        if let location = values.location {
            LocationPreview(location: location)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            LabeledContent("Latitude", value: location.latitude.formatted(.number.precision(.fractionLength(6))))
            LabeledContent("Longitude", value: location.longitude.formatted(.number.precision(.fractionLength(6))))
            if let altitude = location.altitude {
                LabeledContent("Altitude", value: "\(altitude.formatted(.number.precision(.fractionLength(0...1)))) m")
            }
            if let direction = location.direction {
                LabeledContent("Direction", value: "\(direction.formatted(.number.precision(.fractionLength(0...1))))°")
            }
            // 同一行里放两个 borderless 按钮：表单里多个默认样式按钮会被整行点击同时触发。
            HStack {
                Button("Edit Location", systemImage: "mappin.and.ellipse") { sheet?.wrappedValue = .locationPicker }
                Spacer()
                Button("Remove Location", systemImage: "location.slash", role: .destructive) { values.location = nil }
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        } else {
            Button("Add Location", systemImage: "mappin.and.ellipse") { sheet?.wrappedValue = .locationPicker }
        }
    }
}

// MARK: - 弹窗

enum FieldSheet: String, Identifiable {
    case devicePicker, locationPicker
    var id: String { rawValue }
}

private struct FieldSheetKey: EnvironmentKey {
    static let defaultValue: Binding<FieldSheet?>? = nil
}

extension EnvironmentValues {
    var fieldSheet: Binding<FieldSheet?>? {
        get { self[FieldSheetKey.self] }
        set { self[FieldSheetKey.self] = newValue }
    }
}

private struct FieldSheetsModifier: ViewModifier {
    @Binding var values: PhotoMetadata
    let onPresetApplied: ((_ includesLens: Bool) -> Void)?
    @State private var sheet: FieldSheet?

    func body(content: Content) -> some View {
        content
            .environment(\.fieldSheet, $sheet)
            .sheet(item: $sheet) { item in
                switch item {
                case .devicePicker:
                    DevicePickerView { device, lens in
                        values.applyPreset(device: device, lens: lens)
                        onPresetApplied?(lens != nil)
                    }
                case .locationPicker:
                    LocationPickerView(initial: values.location) { values.location = $0 }
                }
            }
    }
}

extension View {
    /// 为内部的 FieldRows 提供设备预设和地图选点弹窗。
    /// `onPresetApplied` 在选择预设后回调（批量编辑用来自动勾选“设备”和“镜头”）。
    func fieldSheets(values: Binding<PhotoMetadata>, onPresetApplied: ((_ includesLens: Bool) -> Void)? = nil) -> some View {
        modifier(FieldSheetsModifier(values: values, onPresetApplied: onPresetApplied))
    }
}

// MARK: - 快门

struct ExposureTimeRow: View {
    @Binding var value: Double?
    @State private var text = ""
    @FocusState private var focused: Bool

    private static let presets = ["1/8000", "1/4000", "1/2000", "1/1000", "1/500", "1/250", "1/120", "1/60", "1/30", "1/15", "1/8", "1/4", "1/2", "1", "2"]

    var body: some View {
        LabeledContent("Shutter Speed") {
            HStack(spacing: 8) {
                TextField("1/120", text: $text)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numbersAndPunctuation)
                    .focused($focused)
                Text("s").foregroundStyle(.secondary)
                Menu {
                    ForEach(Self.presets, id: \.self) { preset in
                        Button(preset) { value = ExposureFormat.parse(preset) }
                    }
                } label: {
                    Image(systemName: "list.bullet.circle")
                }
            }
        }
        .onAppear { text = value.map(ExposureFormat.string) ?? "" }
        .onChange(of: value) { _, newValue in
            if !focused { text = newValue.map(ExposureFormat.string) ?? "" }
        }
        .onChange(of: text) { _, newText in
            guard newText != (value.map(ExposureFormat.string) ?? "") else { return }
            let parsed = newText.isEmpty ? nil : ExposureFormat.parse(newText)
            if newText.isEmpty || parsed != nil { value = parsed }
        }
    }
}

// MARK: - 曝光补偿

struct ExposureBiasRow: View {
    @Binding var value: Double?

    var body: some View {
        LabeledContent("Exposure Compensation") {
            HStack {
                Text(value.map { ($0 > 0 ? "+" : "") + $0.formatted(.number.precision(.fractionLength(1))) + " EV" } ?? String(localized: "Not Set"))
                    .foregroundStyle(value == nil ? .secondary : .primary)
                    .monospacedDigit()
                Stepper("", value: Binding(
                    get: { value ?? 0 },
                    set: { value = (($0 * 3).rounded() / 3 * 100).rounded() / 100 }
                ), in: -8...8, step: 1.0 / 3)
                .labelsHidden()
            }
        }
    }
}

// MARK: - 时间

struct DateTimeRows: View {
    @Binding var values: PhotoMetadata

    var body: some View {
        if let date = values.dateTaken {
            DatePicker("Date Taken", selection: Binding(get: { date }, set: { values.dateTaken = $0 }),
                       displayedComponents: [.date, .hourAndMinute])
                .environment(\.timeZone, values.timeZone)
            LabeledContent("Seconds") {
                Stepper(value: seconds(date), in: 0...59) {
                    Text(String(format: "%02d", seconds(date).wrappedValue)).monospacedDigit()
                }
                .fixedSize()
            }
            Picker("Time Zone", selection: timeZoneBinding) {
                ForEach(timeZoneOptions, id: \.self) { offset in
                    Text("UTC\(TimeZoneFormat.string(offset))").tag(offset)
                }
            }
        } else {
            Button("Add Date Taken", systemImage: "calendar.badge.plus") {
                values.dateTaken = Date()
                values.timeZoneOffset = TimeZone.current.secondsFromGMT()
            }
        }
    }

    private var currentOffset: Int {
        values.timeZoneOffset ?? values.timeZone.secondsFromGMT(for: values.dateTaken ?? Date())
    }

    private var timeZoneOptions: [Int] {
        Array(Set(TimeZoneFormat.common + [currentOffset])).sorted()
    }

    /// 切换时区时保持“墙上时间”不变。
    private var timeZoneBinding: Binding<Int> {
        Binding(get: { currentOffset }, set: { newOffset in
            let old = currentOffset
            values.dateTaken = values.dateTaken?.addingTimeInterval(TimeInterval(old - newOffset))
            values.timeZoneOffset = newOffset
        })
    }

    private func seconds(_ date: Date) -> Binding<Int> {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = values.timeZone
        return Binding(get: { calendar.component(.second, from: date) }, set: { newValue in
            let current = calendar.component(.second, from: date)
            values.dateTaken = date.addingTimeInterval(TimeInterval(newValue - current))
        })
    }
}

// MARK: - 位置预览

struct LocationPreview: View {
    let location: GeoLocation

    var body: some View {
        let coordinate = MapCoordinates.toMap(CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude))
        Map(initialPosition: .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 1500, longitudinalMeters: 1500)),
            interactionModes: []) {
            Marker("", coordinate: coordinate)
        }
        .id(location)
    }
}

/// 地图坐标（中国大陆为 GCJ-02）与 EXIF 坐标（WGS-84）之间的换算。
/// 始终开启：大陆以外的坐标 CoordinateConverter 会原样返回。
enum MapCoordinates {
    static func toMap(_ wgs: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        CoordinateConverter.wgs84ToGCJ02(wgs)
    }

    static func toWGS(_ map: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        CoordinateConverter.gcj02ToWGS84(map)
    }
}
