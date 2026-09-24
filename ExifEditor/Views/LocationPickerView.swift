import CoreLocation
import MapKit
import SwiftUI

/// 地图选点。地图上的坐标是“地图坐标”（中国大陆为 GCJ-02），输出统一转换为 WGS-84。
struct LocationPickerView: View {
    let initial: GeoLocation?
    let onDone: (GeoLocation) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition = .automatic
    /// 当前可见区域；.automatic 模式下一旦出现标注会自动缩放，放针时用它固定相机。
    @State private var visibleRegion: MKCoordinateRegion?
    /// 地图坐标系下的大头针位置
    @State private var pin: CLLocationCoordinate2D?
    @State private var altitude: Double?
    @State private var direction: Double?
    @State private var placeName: String?
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var isLocating = false
    @State private var showManualEntry = false
    @State private var errorMessage: String?
    @State private var locator = OneShotLocator()

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                Map(position: $position) {
                    if let pin {
                        Marker(placeName ?? "", coordinate: pin)
                    }
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    visibleRegion = context.region
                }
                .mapControls {
                    MapCompass()
                    MapScaleView()
                }
                .onTapGesture { point in
                    if let coordinate = proxy.convert(point, from: .local) {
                        setPin(coordinate, moveCamera: false)
                    }
                }
            }
            .overlay(alignment: .top) { searchResults }
            .safeAreaInset(edge: .bottom) { bottomPanel }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search places"))
            .onSubmit(of: .search) { Task { await search() } }
            .onChange(of: query) { _, newValue in if newValue.isEmpty { results = [] } }
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let result = currentWGS { onDone(result) }
                        dismiss()
                    }
                    .disabled(pin == nil)
                }
            }
            .sheet(isPresented: $showManualEntry) {
                ManualCoordinateView(initial: currentWGS) { location in
                    altitude = location.altitude
                    direction = location.direction
                    setPin(MapCoordinates.toMap(CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)), moveCamera: true)
                }
            }
            .alert("Location Unavailable", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear(perform: setUpInitial)
        }
    }

    private var currentWGS: GeoLocation? {
        guard let pin else { return nil }
        let wgs = MapCoordinates.toWGS(pin)
        return GeoLocation(latitude: wgs.latitude, longitude: wgs.longitude, altitude: altitude, direction: direction)
    }

    // MARK: 子视图

    @ViewBuilder
    private var searchResults: some View {
        if !results.isEmpty {
            List(results, id: \.self) { item in
                Button {
                    results = []
                    placeName = item.name
                    setPin(item.placemark.coordinate, moveCamera: true, geocode: false)
                } label: {
                    VStack(alignment: .leading) {
                        Text(item.name ?? "").foregroundStyle(.primary)
                        if let address = item.placemark.title {
                            Text(address).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .frame(maxHeight: 300)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 8)
            .padding()
        }
    }

    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let wgs = currentWGS {
                if let placeName { Text(placeName).font(.headline).lineLimit(2) }
                Text(verbatim: String(format: "%.6f, %.6f", wgs.latitude, wgs.longitude))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } else {
                Text("Tap the map to drop a pin, or search for a place.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button {
                    Task { await useCurrentLocation() }
                } label: {
                    Label("Current Location", systemImage: isLocating ? "hourglass" : "location.fill")
                }
                .disabled(isLocating)
                Spacer()
                Button {
                    showManualEntry = true
                } label: {
                    Label("Coordinates", systemImage: "keyboard")
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }

    // MARK: 动作

    private func setUpInitial() {
        guard let initial else { return }
        altitude = initial.altitude
        direction = initial.direction
        setPin(MapCoordinates.toMap(CLLocationCoordinate2D(latitude: initial.latitude, longitude: initial.longitude)), moveCamera: true)
    }

    private func setPin(_ coordinate: CLLocationCoordinate2D, moveCamera: Bool, geocode: Bool = true) {
        pin = coordinate
        if moveCamera {
            position = .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 2000, longitudinalMeters: 2000))
        } else if let visibleRegion {
            position = .region(visibleRegion)
        }
        if geocode {
            placeName = nil
            Task { await reverseGeocode(coordinate) }
        }
    }

    private func reverseGeocode(_ mapCoordinate: CLLocationCoordinate2D) async {
        let wgs = MapCoordinates.toWGS(mapCoordinate)
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: wgs.latitude, longitude: wgs.longitude))
        guard pin?.latitude == mapCoordinate.latitude, pin?.longitude == mapCoordinate.longitude,
              let p = placemarks?.first else { return }
        placeName = [p.name, p.locality, p.administrativeArea, p.country]
            .compactMap { $0 }
            .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
            .joined(separator: ", ")
    }

    private func search() async {
        guard !query.isEmpty else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let region = position.region ?? visibleRegion { request.region = region }
        results = (try? await MKLocalSearch(request: request).start().mapItems) ?? []
    }

    private func useCurrentLocation() async {
        isLocating = true
        defer { isLocating = false }
        do {
            let location = try await locator.requestLocation()
            altitude = location.verticalAccuracy >= 0 ? location.altitude : nil
            direction = nil
            setPin(MapCoordinates.toMap(location.coordinate), moveCamera: true)
        } catch {
            errorMessage = String(localized: "Allow location access in Settings to use your current location.")
        }
    }
}

// MARK: - 手动输入

private struct ManualCoordinateView: View {
    let initial: GeoLocation?
    let onDone: (GeoLocation) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var altitude: Double?
    @State private var direction: Double?

    private var isValid: Bool {
        guard let latitude, let longitude else { return false }
        return (-90...90).contains(latitude) && (-180...180).contains(longitude)
            && (direction.map { (0..<360).contains($0) } ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NumberRow(title: "Latitude", value: $latitude, maxFractionDigits: 7, allowsNegative: true)
                    NumberRow(title: "Longitude", value: $longitude, maxFractionDigits: 7, allowsNegative: true)
                } footer: {
                    Text("WGS-84 decimal degrees, as used by GPS and EXIF. South and west are negative.")
                }
                Section {
                    NumberRow(title: "Altitude", value: $altitude, unit: "m", maxFractionDigits: 1, allowsNegative: true)
                    NumberRow(title: "Direction", value: $direction, unit: "°", maxFractionDigits: 1)
                } footer: {
                    Text("Optional. Direction is the compass heading the camera faced, 0–359°.")
                }
            }
            .navigationTitle("Enter Coordinates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let latitude, let longitude {
                            onDone(GeoLocation(latitude: latitude, longitude: longitude, altitude: altitude, direction: direction))
                        }
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                latitude = initial?.latitude
                longitude = initial?.longitude
                altitude = initial?.altitude
                direction = initial?.direction
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - 单次定位

@MainActor
final class OneShotLocator: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() async throws -> CLLocation {
        continuation?.resume(throwing: CancellationError())
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            switch manager.authorizationStatus {
            case .notDetermined: manager.requestWhenInUseAuthorization()
            case .denied, .restricted: finish(.failure(CLError(.denied)))
            default: manager.requestLocation()
            }
        }
    }

    private func finish(_ result: Result<CLLocation, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard continuation != nil else { return }
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
            case .denied, .restricted: finish(.failure(CLError(.denied)))
            default: break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in finish(.success(location)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in finish(.failure(error)) }
    }
}
