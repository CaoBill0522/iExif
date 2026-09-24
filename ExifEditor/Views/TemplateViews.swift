import SwiftUI

/// 把当前参数存为模板。
struct SaveTemplateView: View {
    let values: PhotoMetadata

    @Environment(TemplateStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var fields: Set<MetadataField>

    init(values: PhotoMetadata, suggestedFields: Set<MetadataField>) {
        self.values = values
        _fields = State(initialValue: suggestedFields)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Template Name", text: $name)
                }
                Section {
                    ForEach(MetadataField.allCases) { field in
                        Toggle(isOn: Binding(
                            get: { fields.contains(field) },
                            set: { if $0 { fields.insert(field) } else { fields.remove(field) } }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(field.title)
                                Text(TemplateValueSummary.text(for: field, in: values))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                } header: {
                    Text("Included Fields")
                } footer: {
                    Text("Only the included fields are changed when the template is applied.")
                }
            }
            .navigationTitle("New Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.add(MetadataTemplate(name: name.trimmingCharacters(in: .whitespaces), fields: fields, values: values))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || fields.isEmpty)
                }
            }
        }
    }
}

/// 模板页：列表 + 新建 / 编辑。
struct TemplatesView: View {
    @Environment(TemplateStore.self) private var store
    @State private var editing: MetadataTemplate?

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.templates) { template in
                    Button {
                        editing = template
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name).font(.headline).foregroundColor(Color(.label))
                            Text(template.fieldSummary).font(.caption).foregroundColor(Color(.secondaryLabel))
                        }
                    }
                }
                .onDelete { store.delete(at: $0) }
            }
            .overlay {
                if store.templates.isEmpty {
                    ContentUnavailableView("No Templates",
                                           systemImage: "square.stack",
                                           description: Text("Tap + to create a template, or choose More › Save as Template while editing a photo."))
                }
            }
            .navigationTitle("Templates")
            .toolbar {
                if !store.templates.isEmpty {
                    ToolbarItem(placement: .topBarLeading) { EditButton() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New Template", systemImage: "plus") {
                        editing = MetadataTemplate(name: "", fields: [], values: PhotoMetadata())
                    }
                }
            }
            .sheet(item: $editing) { TemplateEditorView(template: $0) }
        }
    }
}

/// 新建或编辑模板：勾选字段并填写值。
struct TemplateEditorView: View {
    @Environment(TemplateStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var template: MetadataTemplate
    private let isNew: Bool

    init(template: MetadataTemplate) {
        _template = State(initialValue: template)
        isNew = template.name.isEmpty && template.fields.isEmpty
    }

    private var canSave: Bool {
        !template.name.trimmingCharacters(in: .whitespaces).isEmpty && !template.fields.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Template Name", text: $template.name)
                } footer: {
                    Text("Only the included fields are changed when the template is applied.")
                }
                ForEach(MetadataField.allCases) { field in
                    let isOn = Binding(
                        get: { template.fields.contains(field) },
                        set: { if $0 { template.fields.insert(field) } else { template.fields.remove(field) } }
                    )
                    Section {
                        Toggle(field.title, isOn: isOn).font(.headline)
                        if isOn.wrappedValue {
                            FieldRows(field: field, values: $template.values)
                        }
                    }
                }
            }
            .listSectionSpacing(.compact)
            .scrollDismissesKeyboard(.interactively)
            .fieldSheets(values: $template.values) { includesLens in
                template.fields.insert(.device)
                if includesLens { template.fields.insert(.lens) }
            }
            .navigationTitle(isNew ? String(localized: "New Template") : String(localized: "Edit Template"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        template.name = template.name.trimmingCharacters(in: .whitespaces)
                        store.save(template)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

enum TemplateValueSummary {
    static func text(for field: MetadataField, in v: PhotoMetadata) -> String {
        let empty = String(localized: "Empty (clears the value)")
        switch field {
        case .device: return [v.make, v.model].compactMap { $0 }.joined(separator: " ").nonEmpty ?? empty
        case .lens: return v.lensModel ?? empty
        case .exposureTime: return v.exposureTime.map { ExposureFormat.string($0) + " s" } ?? empty
        case .iso: return v.iso.map { "ISO \($0)" } ?? empty
        case .exposureBias: return v.exposureBias.map { "\($0.formatted()) EV" } ?? empty
        case .meteringMode: return v.meteringMode.flatMap { MeteringMode(rawValue: $0)?.title } ?? empty
        case .flash: return v.flash.flatMap { FlashMode(rawValue: $0)?.title } ?? empty
        case .whiteBalance: return v.whiteBalance.flatMap { WhiteBalanceMode(rawValue: $0)?.title } ?? empty
        case .dateTime: return v.dateTaken.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? empty
        case .location: return v.location.map { String(format: "%.5f, %.5f", $0.latitude, $0.longitude) } ?? empty
        case .artist: return v.artist ?? empty
        case .copyright: return v.copyright ?? empty
        case .imageDescription: return v.imageDescription ?? empty
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
