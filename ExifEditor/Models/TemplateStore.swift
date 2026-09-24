import Foundation
import Observation

struct MetadataTemplate: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var fields: Set<MetadataField>
    var values: PhotoMetadata
    var createdAt = Date()

    var fieldSummary: String {
        MetadataField.allCases.filter(fields.contains).map(\.title).formatted(.list(type: .and, width: .narrow))
    }
}

@MainActor
@Observable
final class TemplateStore {
    private(set) var templates: [MetadataTemplate] = []

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("templates.json")
    }()

    init() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([MetadataTemplate].self, from: data) {
            templates = decoded
        }
    }

    func add(_ template: MetadataTemplate) {
        templates.insert(template, at: 0)
        persist()
    }

    /// 新增或按 id 覆盖。
    func save(_ template: MetadataTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
        } else {
            templates.insert(template, at: 0)
        }
        persist()
    }

    func delete(at offsets: IndexSet) {
        templates.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(templates) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
