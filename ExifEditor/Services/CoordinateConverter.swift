import CoreLocation

/// WGS-84 与 GCJ-02 互转。
///
/// Apple 地图在中国大陆使用 GCJ-02（地图显示、搜索结果都在这个坐标系），
/// 而 EXIF 与 CLLocationManager 使用 WGS-84。
enum CoordinateConverter {
    private static let a = 6378245.0
    private static let ee = 0.00669342162296594323

    static func isInMainlandChina(_ c: CLLocationCoordinate2D) -> Bool {
        let inside = regions.contains { $0.contains(c) }
        return inside && !excludes.contains { $0.contains(c) }
    }

    static func wgs84ToGCJ02(_ c: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        guard isInMainlandChina(c) else { return c }
        let d = delta(c)
        return CLLocationCoordinate2D(latitude: c.latitude + d.latitude, longitude: c.longitude + d.longitude)
    }

    /// 迭代求逆，精度约 1e-7 度（厘米级）。
    static func gcj02ToWGS84(_ c: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        guard isInMainlandChina(c) else { return c }
        var wgs = CLLocationCoordinate2D(latitude: c.latitude, longitude: c.longitude)
        for _ in 0..<10 {
            let d = delta(wgs)
            let next = CLLocationCoordinate2D(latitude: c.latitude - d.latitude, longitude: c.longitude - d.longitude)
            if abs(next.latitude - wgs.latitude) < 1e-9, abs(next.longitude - wgs.longitude) < 1e-9 { return next }
            wgs = next
        }
        return wgs
    }

    private static func delta(_ c: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let x = c.longitude - 105.0, y = c.latitude - 35.0
        var dLat = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        dLat += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        dLat += (20.0 * sin(y * .pi) + 40.0 * sin(y / 3.0 * .pi)) * 2.0 / 3.0
        dLat += (160.0 * sin(y / 12.0 * .pi) + 320 * sin(y * .pi / 30.0)) * 2.0 / 3.0
        var dLon = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        dLon += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        dLon += (20.0 * sin(x * .pi) + 40.0 * sin(x / 3.0 * .pi)) * 2.0 / 3.0
        dLon += (150.0 * sin(x / 12.0 * .pi) + 300.0 * sin(x / 30.0 * .pi)) * 2.0 / 3.0
        let radLat = c.latitude / 180.0 * .pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)
        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * .pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * .pi)
        return CLLocationCoordinate2D(latitude: dLat, longitude: dLon)
    }

    private struct Rect {
        let north: Double, west: Double, south: Double, east: Double
        func contains(_ c: CLLocationCoordinate2D) -> Bool {
            c.latitude <= north && c.latitude >= south && c.longitude >= west && c.longitude <= east
        }
    }

    // 中国大陆近似范围（多个矩形拼接），并排除台湾、港澳及周边国家。
    private static let regions = [
        Rect(north: 49.2204, west: 79.4462, south: 42.8899, east: 96.3300),
        Rect(north: 54.1415, west: 109.6872, south: 39.3742, east: 135.0002),
        Rect(north: 42.8899, west: 73.1246, south: 29.5297, east: 124.1433),
        Rect(north: 29.5297, west: 82.9684, south: 26.7186, east: 97.0352),
        Rect(north: 29.5297, west: 97.0253, south: 20.4141, east: 124.3674),
        Rect(north: 20.4141, west: 107.9758, south: 17.8715, east: 111.7441),
    ]
    private static let excludes = [
        Rect(north: 25.3986, west: 119.9213, south: 21.7850, east: 122.4976), // 台湾
        Rect(north: 22.5600, west: 113.8200, south: 22.1400, east: 114.4400), // 香港
        Rect(north: 22.2200, west: 113.5200, south: 22.1000, east: 113.6200), // 澳门
        Rect(north: 22.2840, west: 101.8652, south: 20.0988, east: 106.6650),
        Rect(north: 21.5422, west: 106.4525, south: 20.4878, east: 108.0510),
        Rect(north: 55.8175, west: 109.0323, south: 50.3257, east: 119.1270),
        Rect(north: 55.8175, west: 127.4568, south: 49.5574, east: 137.0227),
        Rect(north: 44.8922, west: 131.2662, south: 42.5692, east: 137.0227),
    ]
}
