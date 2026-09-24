import SwiftUI

struct BatchEditView: View {
    let items: [PhotoItem]

    enum DateMode: String, CaseIterable, Identifiable {
        case set, shift
        var id: String { rawValue }
        var title: String {
            switch self {
            case .set: String(localized: "Set Same Time")
            case .shift: String(localized: "Shift All")
            }
        }
    }

    enum BatchSaveMode: String, CaseIterable, Identifiable {
        case saveAsNew, replaceOriginal, albumOnly
        var id: String { rawValue }
        var title: String {
            switch self {
            case .saveAsNew: SaveMode.saveAsNew.title
            case .replaceOriginal: SaveMode.replaceOriginal.title
            case .albumOnly: String(localized: "Edit in Photos Only")
            }
        }
    }

    @Environment(TemplateStore.self) private var templates
    @Environment(\.dismiss) private var dismiss

    @State private var values: PhotoMetadata
    @State private var enabled: Set<MetadataField> = []
    @State private var dateMode: DateMode = .shift
    @State private var shift = 0
    @State private var saveMode: BatchSaveMode
    @State private var stripMakerNote = UserDefaults.standard.stripMakerNoteByDefault
    @State private var matchResolution = UserDefaults.standard.matchResolutionByDefault
    @State private var progress: Double?
    @State private var alert: AlertInfo?

    init(items: [PhotoItem]) {
        self.items = items
        _values = State(initialValue: items.first?.original ?? PhotoMetadata())
        let allFromLibrary = items.allSatisfy { $0.assetIdentifier != nil }
        _saveMode = State(initialValue: allFromLibrary && UserDefaults.standard.defaultSaveMode == .replaceOriginal ? .replaceOriginal : .saveAsNew)
    }

    private var allFromLibrary: Bool { items.allSatisfy { $0.assetIdentifier != nil } }

    /// 「仅修改相册信息」只支持时间和位置。
    private var effectiveFields: Set<MetadataField> {
        saveMode == .albumOnly ? enabled.intersection([.dateTime, .location]) : enabled
    }

    private var canSave: Bool {
        guard progress == nil else { return false }
        if effectiveFields.isEmpty { return saveMode != .albumOnly && (stripMakerNote || matchResolution) }
        return !(effectiveFields == [.dateTime] && dateMode == .shift && shift == 0)
    }

    var body: some View {
        Form {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(items) { item in
                            if let thumbnail = item.thumbnail {
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 64, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                if !templates.templates.isEmpty {
                    Menu {
                        ForEach(templates.templates) { template in
                            Button(template.name) {
                                values.apply(template.fields, from: template.values)
                                enabled.formUnion(template.fields)
                                if template.fields.contains(.dateTime) { dateMode = .set }
                            }
                        }
                    } label: {
                        Label("Apply Template", systemImage: "square.stack")
                    }
                }
            } header: {
                Text("\(items.count) Photos")
            } footer: {
                Text("Turn on the fields to change. Fields that are off keep each photo's own values. Initial values come from the first photo.")
            }

            ForEach(MetadataField.allCases) { field in
                fieldSection(field)
            }

            saveOptionsSection
        }
        .listSectionSpacing(.compact)
        .scrollDismissesKeyboard(.interactively)
        .fieldSheets(values: $values) { includesLens in
            enabled.insert(.device)
            if includesLens { enabled.insert(.lens) }
        }
        .navigationTitle("Batch Edit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(!canSave)
            }
        }
        .disabled(progress != nil)
        .overlay {
            if let progress {
                VStack(spacing: 12) {
                    ProgressView(value: progress)
                    Text("Saving \(Int(progress * Double(items.count))) of \(items.count)…")
                        .font(.subheadline)
                        .monospacedDigit()
                }
                .padding(24)
                .frame(maxWidth: 280)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .alert(item: $alert) { info in
            Alert(title: Text(info.title), message: Text(info.message), dismissButton: .default(Text("OK")) {
                if info.dismissesEditor { dismiss() }
            })
        }
    }

    @ViewBuilder
    private func fieldSection(_ field: MetadataField) -> some View {
        let isOn = Binding(
            get: { enabled.contains(field) },
            set: { if $0 { enabled.insert(field) } else { enabled.remove(field) } }
        )
        let unsupported = saveMode == .albumOnly && ![.dateTime, .location].contains(field)
        Section {
            Toggle(field.title, isOn: isOn)
                .font(.headline)
                .disabled(unsupported)
            if isOn.wrappedValue && !unsupported {
                if field == .dateTime {
                    Picker("Mode", selection: $dateMode) {
                        ForEach(DateMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if dateMode == .set {
                        FieldRows(field: .dateTime, values: $values)
                    } else {
                        TimeShiftRows(seconds: $shift)
                    }
                } else if field == .location {
                    FieldRows(field: .location, values: $values)
                    if values.location == nil {
                        Text("No location set: the location will be removed from all photos.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    FieldRows(field: field, values: $values)
                }
            }
        }
    }

    private var saveOptionsSection: some View {
        Section {
            Picker("Save Mode", selection: $saveMode) {
                ForEach(BatchSaveMode.allCases.filter { allFromLibrary || $0 == .saveAsNew }) { Text($0.title).tag($0) }
            }
            if saveMode != .albumOnly {
                Toggle("Remove MakerNote", isOn: $stripMakerNote)
                Toggle("Match Device Resolution", isOn: $matchResolution)
            }
        } header: {
            Text("Save Options")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                switch saveMode {
                case .saveAsNew: Text(SaveMode.saveAsNew.detail)
                case .replaceOriginal: Text(SaveMode.replaceOriginal.detail)
                case .albumOnly: Text("Only the date and location that Photos shows are changed. No new photos are created and the files' EXIF stays unchanged.")
                }
                if saveMode != .albumOnly {
                    Text("Photos are converted to the device's default format when needed (see Settings).")
                    if matchResolution {
                        Text("Each photo is resized to the device's camera resolution and re-encoded; small photos may look blurry.")
                    }
                    if items.contains(where: \.isLivePhoto) {
                        Text("Live Photos keep their video, and its date, location and device are updated to match.")
                    }
                }
            }
        }
    }

    // MARK: 保存

    private func save() async {
        if saveMode == .albumOnly {
            await saveAlbumOnly()
            return
        }

        progress = 0
        defer { progress = nil }
        var failures = 0
        var savedOriginals: [String] = []

        for (index, item) in items.enumerated() {
            var fields = enabled
            var itemValues = values
            if enabled.contains(.dateTime), dateMode == .shift {
                if let date = item.original.dateTaken {
                    itemValues.dateTaken = date.addingTimeInterval(TimeInterval(shift))
                    itemValues.timeZoneOffset = item.original.timeZoneOffset
                } else {
                    fields.remove(.dateTime) // 没有原始时间的照片无法平移
                }
            }
            do {
                let rendered = try await item.render(fields: fields, values: itemValues, stripMakerNote: stripMakerNote,
                                                     matchResolution: matchResolution)
                var final = item.original
                final.apply(fields, from: itemValues)
                try await PhotoLibraryService.saveNewPhoto(data: rendered.data, filename: rendered.filename,
                                                           pairedVideo: rendered.pairedVideoURL,
                                                           creationDate: final.dateTaken, location: final.location)
                if let id = item.assetIdentifier { savedOriginals.append(id) }
            } catch {
                failures += 1
            }
            progress = Double(index + 1) / Double(items.count)
        }

        var message = failures == 0
            ? String(localized: "\(items.count - failures) photos were saved to your library.")
            : String(localized: "\(items.count - failures) photos were saved; \(failures) failed.")
        if saveMode == .replaceOriginal, !savedOriginals.isEmpty {
            do {
                try await PhotoLibraryService.deleteAssets(withIdentifiers: savedOriginals)
                message += "\n" + String(localized: "The originals were moved to Recently Deleted.")
            } catch {
                message += "\n" + String(localized: "The originals were kept.")
            }
        }
        alert = AlertInfo(title: String(localized: "Done"), message: message, dismissesEditor: failures == 0)
    }

    private func saveAlbumOnly() async {
        let ids = items.compactMap(\.assetIdentifier)
        let dateEnabled = enabled.contains(.dateTime)
        let mode = dateMode, shift = shift, date = values.dateTaken
        do {
            try await PhotoLibraryService.updateAlbumInfo(assetIdentifiers: ids, date: { asset in
                guard dateEnabled else { return nil }
                return mode == .set ? date : asset.creationDate?.addingTimeInterval(TimeInterval(shift))
            }, location: enabled.contains(.location) ? .some(values.location) : .none)
            alert = AlertInfo(title: String(localized: "Updated"),
                              message: String(localized: "The Photos app now shows the new date and location."),
                              dismissesEditor: true)
        } catch {
            alert = AlertInfo(error: error)
        }
    }
}
