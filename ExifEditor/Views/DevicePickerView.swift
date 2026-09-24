import SwiftUI

/// 选择设备 → 选择镜头。
struct DevicePickerView: View {
    let onSelect: (DevicePreset, LensPreset?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var family: DevicePreset.Family = .iPhone
    @State private var query = ""

    private var groupedDevices: [(year: Int, devices: [DevicePreset])] {
        let all = DeviceCatalogStore.shared.devices(in: family)
        let filtered = query.isEmpty ? all : all.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
        return Dictionary(grouping: filtered, by: \.year)
            .map { ($0.key, $0.value) }
            .sorted { $0.year > $1.year }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedDevices, id: \.year) { group in
                    Section(String(group.year)) {
                        ForEach(group.devices) { device in
                            NavigationLink(value: device) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.displayName)
                                    Text(device.lenses.map(\.localizedKind).formatted(.list(type: .and, width: .narrow)))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .overlay {
                if groupedDevices.isEmpty { ContentUnavailableView.search(text: query) }
            }
            .searchable(text: $query, prompt: Text("Search models"))
            .safeAreaInset(edge: .top) {
                Picker("Device Type", selection: $family) {
                    Text("iPhone").tag(DevicePreset.Family.iPhone)
                    Text("iPad").tag(DevicePreset.Family.iPad)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(.bar)
            }
            .navigationTitle("Device Presets")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: DevicePreset.self) { device in
                LensPickerView(device: device) { lens in
                    onSelect(device, lens)
                    dismiss()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct LensPickerView: View {
    let device: DevicePreset
    let onSelect: (LensPreset?) -> Void

    var body: some View {
        List {
            Section {
                ForEach(device.lenses) { lens in
                    Button {
                        onSelect(lens)
                    } label: {
                        HStack {
                            Image(systemName: lens.position == .front ? "person.crop.square" : "camera.aperture")
                                .foregroundStyle(.tint)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(lens.localizedKind).foregroundColor(Color(.label))
                                    Text(lens.summary).foregroundColor(Color(.secondaryLabel)).monospacedDigit()
                                    if lens.estimated == true {
                                        Text("Estimated")
                                            .font(.caption2.weight(.medium))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.orange.opacity(0.15), in: Capsule())
                                            .foregroundStyle(.orange)
                                    }
                                }
                                Text(lens.lensModel)
                                    .font(.caption)
                                    .foregroundColor(Color(.secondaryLabel))
                            }
                        }
                    }
                }
            } header: {
                Text("Lens")
            } footer: {
                if device.lenses.contains(where: { $0.estimated == true }) {
                    Text("Fills in make, model, lens, aperture and focal length. Estimated lenses are based on published specs because no original sample was available.")
                } else {
                    Text("Fills in make, model, lens, aperture and focal length.")
                }
            }

            Section {
                Button("Use Device Only") { onSelect(nil) }
            } footer: {
                Text("Changes make, model and software only; lens fields stay the same.")
            }
        }
        .navigationTitle(device.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
