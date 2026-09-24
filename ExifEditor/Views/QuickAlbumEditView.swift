import Photos
import SwiftUI

/// 只改「照片」App 里的拍摄时间和位置（PHAsset 属性），不生成新照片、不改文件 EXIF。
struct QuickAlbumEditView: View {
    let assetIdentifiers: [String]
    let initialDate: Date?
    let initialLocation: GeoLocation?

    enum DateChange: String, CaseIterable, Identifiable {
        case keep, set, shift
        var id: String { rawValue }
        var title: String {
            switch self {
            case .keep: String(localized: "Don't Change")
            case .set: String(localized: "Set To")
            case .shift: String(localized: "Shift By")
            }
        }
    }

    enum LocationChange: String, CaseIterable, Identifiable {
        case keep, set, remove
        var id: String { rawValue }
        var title: String {
            switch self {
            case .keep: String(localized: "Don't Change")
            case .set: String(localized: "Set To")
            case .remove: String(localized: "Remove")
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var dateChange: DateChange
    @State private var date: Date
    @State private var shift = 0
    @State private var locationChange: LocationChange = .keep
    @State private var values = PhotoMetadata()
    @State private var isWorking = false
    @State private var alert: AlertInfo?

    init(assetIdentifiers: [String], initialDate: Date?, initialLocation: GeoLocation?) {
        self.assetIdentifiers = assetIdentifiers
        self.initialDate = initialDate
        self.initialLocation = initialLocation
        _dateChange = State(initialValue: assetIdentifiers.count == 1 ? .set : .keep)
        _date = State(initialValue: initialDate ?? Date())
        var v = PhotoMetadata()
        v.location = initialLocation
        _values = State(initialValue: v)
    }

    private var canApply: Bool {
        (dateChange != .keep && !(dateChange == .shift && shift == 0))
            || locationChange == .remove
            || (locationChange == .set && values.location != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Date", selection: $dateChange) {
                        ForEach(DateChange.allCases) { Text($0.title).tag($0) }
                    }
                    switch dateChange {
                    case .keep: EmptyView()
                    case .set: DatePicker("Date Taken", selection: $date)
                    case .shift: TimeShiftRows(seconds: $shift)
                    }
                } header: {
                    Text("Date Taken")
                }

                Section("Location") {
                    Picker("Location", selection: $locationChange) {
                        ForEach(LocationChange.allCases) { Text($0.title).tag($0) }
                    }
                    if locationChange == .set {
                        FieldRows(field: .location, values: $values)
                    }
                }

                Section {
                } footer: {
                    Text("Only what the Photos app shows is changed, and no new photo is created. The EXIF inside the file stays the same, so exporting the original file shows the old values.")
                }
            }
            .fieldSheets(values: $values)
            .navigationTitle(assetIdentifiers.count == 1 ? String(localized: "Edit in Photos") : String(localized: "Edit \(assetIdentifiers.count) Photos in Photos"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { Task { await apply() } }
                        .disabled(!canApply || isWorking)
                }
            }
            .alert(item: $alert) { info in
                Alert(title: Text(info.title), message: Text(info.message), dismissButton: .default(Text("OK")) {
                    if info.dismissesEditor { dismiss() }
                })
            }
        }
    }

    private func apply() async {
        isWorking = true
        defer { isWorking = false }
        let dateChange = dateChange, date = date, shift = shift
        let location: GeoLocation?? = switch locationChange {
        case .keep: .none
        case .set: .some(values.location)
        case .remove: .some(nil)
        }
        do {
            try await PhotoLibraryService.updateAlbumInfo(assetIdentifiers: assetIdentifiers, date: { asset in
                switch dateChange {
                case .keep: nil
                case .set: date
                case .shift: asset.creationDate?.addingTimeInterval(TimeInterval(shift))
                }
            }, location: location)
            alert = AlertInfo(title: String(localized: "Updated"),
                              message: String(localized: "The Photos app now shows the new date and location."),
                              dismissesEditor: true)
        } catch {
            alert = AlertInfo(error: error)
        }
    }
}
