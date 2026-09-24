import SwiftUI
import UniformTypeIdentifiers

struct EditorView: View {
    let item: PhotoItem

    @Environment(TemplateStore.self) private var templates
    @Environment(\.dismiss) private var dismiss

    @State private var values: PhotoMetadata
    @State private var saveMode: SaveMode
    @State private var stripMakerNote: Bool
    @State private var matchResolution: Bool
    @State private var isWorking = false
    @State private var alert: AlertInfo?
    @State private var showSaveTemplate = false
    @State private var showQuickEdit = false
    @State private var shareItem: ShareItem?
    @State private var exportDocument: ImageFileDocument?
    @State private var exportName = ""
    @State private var exportType: UTType = .jpeg

    init(item: PhotoItem) {
        self.item = item
        _values = State(initialValue: item.original)
        _saveMode = State(initialValue: item.assetIdentifier == nil ? .saveAsNew : UserDefaults.standard.defaultSaveMode)
        _stripMakerNote = State(initialValue: UserDefaults.standard.stripMakerNoteByDefault)
        _matchResolution = State(initialValue: UserDefaults.standard.matchResolutionByDefault)
    }

    private var changedFields: Set<MetadataField> { values.changedFields(comparedTo: item.original) }
    private var hasMakerNote: Bool { item.properties["{MakerApple}"] != nil }
    private var plan: OutputPlan {
        item.outputPlan(fields: changedFields, values: values, matchResolution: matchResolution)
    }
    private var hasChanges: Bool { !changedFields.isEmpty || (stripMakerNote && hasMakerNote) || plan.reencodes }

    var body: some View {
        Form {
            headerSection

            Section("Device") { FieldRows(field: .device, values: $values) }
            Section("Lens") { FieldRows(field: .lens, values: $values) }
            Section("Exposure") {
                ForEach([MetadataField.exposureTime, .iso, .exposureBias, .meteringMode, .flash, .whiteBalance]) {
                    FieldRows(field: $0, values: $values)
                }
            }
            Section("Date Taken") { FieldRows(field: .dateTime, values: $values) }
            Section("Location") { FieldRows(field: .location, values: $values) }
            Section("Author & Copyright") {
                ForEach([MetadataField.artist, .copyright, .imageDescription]) {
                    FieldRows(field: $0, values: $values)
                }
            }

            if item.assetIdentifier != nil {
                Section {
                    Button("Edit Date & Location in Photos Only", systemImage: "bolt") {
                        showQuickEdit = true
                    }
                } footer: {
                    Text("Changes only what the Photos app shows, without creating a new photo. The EXIF inside the file stays unchanged.")
                }
            }

            saveOptionsSection
        }
        .scrollDismissesKeyboard(.interactively)
        .fieldSheets(values: $values)
        .navigationTitle(item.filename)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .disabled(isWorking)
        .overlay { if isWorking { ProgressView().controlSize(.large) } }
        .sheet(isPresented: $showSaveTemplate) {
            SaveTemplateView(values: values, suggestedFields: changedFields.isEmpty ? Set(MetadataField.allCases) : changedFields)
        }
        .sheet(isPresented: $showQuickEdit) {
            if let id = item.assetIdentifier {
                QuickAlbumEditView(assetIdentifiers: [id], initialDate: values.dateTaken, initialLocation: values.location)
            }
        }
        .sheet(item: $shareItem) { ShareSheet(items: [$0.url]) }
        .fileExporter(isPresented: Binding(get: { exportDocument != nil }, set: { if !$0 { exportDocument = nil } }),
                      document: exportDocument, contentType: exportType, defaultFilename: exportName) { result in
            if case .failure(let error) = result { alert = AlertInfo(error: error) }
        }
        .alert(item: $alert) { info in
            Alert(title: Text(info.title), message: Text(info.message), dismissButton: .default(Text("OK")) {
                if info.dismissesEditor { dismiss() }
            })
        }
    }

    // MARK: 区块

    private var headerSection: some View {
        Section {
            HStack(alignment: .top, spacing: 14) {
                if let thumbnail = item.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.filename).font(.headline).lineLimit(2)
                    Text(detailLine).font(.subheadline).foregroundStyle(.secondary)
                    if item.isLivePhoto {
                        Label("Live Photo", systemImage: "livephoto")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !changedFields.isEmpty {
                        Text("Changed fields: \(changedFields.count)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
    }

    /// 例如 “HEIC · 5712×4284”
    private var outputSummary: String {
        let plan = plan
        var parts = [plan.fileExtension]
        if let size = plan.pixelSize ?? item.pixelSize { parts.append("\(Int(size.width))×\(Int(size.height))") }
        return parts.joined(separator: " · ")
    }

    private var detailLine: String {
        var parts = [item.formatName, ByteCountFormatter.string(fromByteCount: Int64(item.data.count), countStyle: .file)]
        if let size = item.pixelSize { parts.insert("\(Int(size.width))×\(Int(size.height))", at: 1) }
        return parts.joined(separator: " · ")
    }

    private var saveOptionsSection: some View {
        Section {
            if item.assetIdentifier != nil {
                Picker("Save Mode", selection: $saveMode) {
                    ForEach(SaveMode.allCases) { Text($0.title).tag($0) }
                }
            }
            Toggle("Remove MakerNote", isOn: $stripMakerNote)
                .disabled(!hasMakerNote)
            Toggle("Match Device Resolution", isOn: $matchResolution)
            LabeledContent("Output", value: outputSummary)
        } header: {
            Text("Save Options")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                if item.assetIdentifier != nil { Text(saveMode.detail) }
                Text(hasMakerNote
                     ? "MakerNote is Apple's private camera data. Remove it if it could contradict the edited device info."
                     : "This photo has no MakerNote.")
                OutputNotes(plan: plan, isLivePhoto: item.isLivePhoto,
                            keepsMakerNote: item.keepsMakerNoteForLive(plan: plan, stripMakerNote: stripMakerNote))
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Menu("Apply Template", systemImage: "square.stack") {
                    if templates.templates.isEmpty {
                        Text("No templates yet")
                    }
                    ForEach(templates.templates) { template in
                        Button(template.name) {
                            values.apply(template.fields, from: template.values)
                        }
                    }
                }
                Button("Save as Template…", systemImage: "square.and.arrow.down.on.square") {
                    showSaveTemplate = true
                }
                Divider()
                Button("Export to Files…", systemImage: "folder") { Task { await export(toFiles: true) } }
                Button("Share…", systemImage: "square.and.arrow.up") { Task { await export(toFiles: false) } }
                Divider()
                Button("Revert Changes", systemImage: "arrow.uturn.backward", role: .destructive) {
                    values = item.original
                }
                .disabled(changedFields.isEmpty)
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
        // iOS 26 会把相邻按钮合并进同一个胶囊，用固定间隔把“更多”和“保存”分开。
        if #available(iOS 26.0, *) {
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Save") { Task { await save() } }
                .fontWeight(.semibold)
                .disabled(!hasChanges)
        }
    }

    // MARK: 动作

    private func render(includeVideo: Bool = true) async throws -> PhotoItem.Rendered {
        try await item.render(fields: changedFields, values: values, stripMakerNote: stripMakerNote,
                              matchResolution: matchResolution, includeVideo: includeVideo)
    }

    private func save() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let rendered = try await render()
            var final = item.original
            final.apply(changedFields, from: values)
            try await PhotoLibraryService.saveNewPhoto(data: rendered.data, filename: rendered.filename,
                                                       pairedVideo: rendered.pairedVideoURL,
                                                       creationDate: final.dateTaken, location: final.location)

            var message = String(localized: "The edited photo was saved to your library.")
            if saveMode == .replaceOriginal, let id = item.assetIdentifier {
                do {
                    try await PhotoLibraryService.deleteAssets(withIdentifiers: [id])
                    message = String(localized: "The edited photo was saved and the original was moved to Recently Deleted.")
                } catch {
                    message = String(localized: "The edited photo was saved. The original was kept.")
                }
            }
            alert = AlertInfo(title: String(localized: "Saved"), message: message, dismissesEditor: true)
        } catch {
            alert = AlertInfo(error: error)
        }
    }

    private func export(toFiles: Bool) async {
        isWorking = true
        defer { isWorking = false }
        do {
            // 导出 / 分享只包含照片本身，实况视频不导出。
            let rendered = try await render(includeVideo: false)
            if toFiles {
                exportName = rendered.filename
                exportType = plan.type
                exportDocument = ImageFileDocument(data: rendered.data)
            } else {
                shareItem = ShareItem(url: try TemporaryFile.write(rendered.data, filename: rendered.filename))
            }
        } catch {
            alert = AlertInfo(error: error)
        }
    }
}
