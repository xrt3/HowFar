//
//  TripListSupport.swift
//  MileMate
//

import CoreLocation
import Foundation
import MapKit
import SwiftUI

// MARK: - Trip 首尾坐标

extension Trip {
    /// 优先使用模型缓存坐标；旧数据无缓存时从轨迹点解析。
    func resolvedEndpointCoordinates() -> (start: CLLocationCoordinate2D?, end: CLLocationCoordinate2D?) {
        let start: CLLocationCoordinate2D? = {
            guard let la = startLatitude, let lo = startLongitude else { return nil }
            return CLLocationCoordinate2D(latitude: la, longitude: lo)
        }()
        let end: CLLocationCoordinate2D? = {
            guard let la = endLatitude, let lo = endLongitude else { return nil }
            return CLLocationCoordinate2D(latitude: la, longitude: lo)
        }()
        if start != nil || end != nil {
            return (start, end ?? start)
        }
        let sorted = points.sorted { $0.timestamp < $1.timestamp }
        guard let first = sorted.first else { return (nil, nil) }
        let s = CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)
        guard let last = sorted.last else { return (s, nil) }
        let e = CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude)
        return (s, e)
    }

    /// 供仅导入 SwiftUI 的列表行使用，避免直接依赖 `CLLocationCoordinate2D`。
    func resolvedEndpointLatLon() -> (startLat: Double?, startLon: Double?, endLat: Double?, endLon: Double?) {
        let (s, e) = resolvedEndpointCoordinates()
        return (s?.latitude, s?.longitude, e?.latitude, e?.longitude)
    }
}

// MARK: - 按年月分组

struct MonthSection: Identifiable {
    var id: String { "\(year)-\(month)" }
    let year: Int
    let month: Int
    let trips: [Trip]

    var totalDistanceKm: Double {
        trips.reduce(0) { $0 + $1.totalDistanceMeters } / 1000
    }

    var tripCount: Int { trips.count }

    var ongoingCount: Int {
        trips.filter { $0.endedAt == nil }.count
    }

    /// 仅已结束行程的时长之和（秒）。
    var completedDurationSeconds: TimeInterval {
        trips.compactMap { trip -> TimeInterval? in
            guard let end = trip.endedAt else { return nil }
            return end.timeIntervalSince(trip.startedAt)
        }
        .reduce(0, +)
    }

    static func group(_ trips: [Trip]) -> [MonthSection] {
        let cal = Calendar.current
        var buckets: [String: [Trip]] = [:]
        for trip in trips {
            let c = cal.dateComponents([.year, .month], from: trip.startedAt)
            guard let y = c.year, let m = c.month else { continue }
            let key = "\(y)-\(m)"
            buckets[key, default: []].append(trip)
        }
        return buckets.compactMap { key, list -> MonthSection? in
            let parts = key.split(separator: "-")
            guard parts.count == 2,
                  let y = Int(parts[0]),
                  let m = Int(parts[1])
            else { return nil }
            let sortedTrips = list.sorted { $0.startedAt > $1.startedAt }
            return MonthSection(year: y, month: m, trips: sortedTrips)
        }
        .sorted { lhs, rhs in
            if lhs.year != rhs.year { return lhs.year > rhs.year }
            return lhs.month > rhs.month
        }
    }
}

enum MonthSectionFormatting {
    private static let titleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.setLocalizedDateFormatFromTemplate("yMMM")
        return f
    }()

    static func monthTitle(year: Int, month: Int) -> String {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = 1
        guard let date = Calendar.current.date(from: c) else {
            return "\(year)年\(month)月"
        }
        return titleFormatter.string(from: date)
    }

    static func footerText(for section: MonthSection) -> String {
        var parts: [String] = [
            "\(section.tripCount) 次行程",
            String(format: "%.2f 公里", section.totalDistanceKm),
        ]
        if section.completedDurationSeconds > 0 {
            parts.append(durationLabel(section.completedDurationSeconds))
        }
        if section.ongoingCount > 0 {
            parts.append("进行中 \(section.ongoingCount)")
        }
        return parts.joined(separator: " · ")
    }

    private static func durationLabel(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        if h > 0 {
            return m > 0 ? "约 \(h) 小时 \(m) 分" : "约 \(h) 小时"
        }
        if m > 0 {
            return "约 \(m) 分钟"
        }
        return "不足 1 分钟"
    }
}

// MARK: - 逆地理缓存

@MainActor
final class TripGeocodeCache {
    static let shared = TripGeocodeCache()

    private var storage: [String: String] = [:]

    private init() {}

    func address(latitude: Double?, longitude: Double?) async -> String {
        guard let lat = latitude, let lon = longitude else { return "—" }
        let key = String(format: "%.4f,%.4f", lat, lon)
        if let cached = storage[key] { return cached }

        let location = CLLocation(latitude: lat, longitude: lon)
        let fallback = String(format: "%.4f°, %.4f°", lat, lon)
        guard let request = MKReverseGeocodingRequest(location: location) else {
            storage[key] = fallback
            return fallback
        }

        let text: String
        do {
            let items = try await request.mapItems
            if let item = items.first {
                text = Self.format(mapItem: item)
            } else {
                text = fallback
            }
        } catch {
            text = fallback
        }
        storage[key] = text
        return text
    }

    private nonisolated static func format(mapItem: MKMapItem) -> String {
        if let reps = mapItem.addressRepresentations {
            if let line = reps.fullAddress(includingRegion: false, singleLine: true), !line.isEmpty {
                return line
            }
            if let city = reps.cityWithContext, !city.isEmpty {
                return city
            }
        }
        if let name = mapItem.name, !name.isEmpty {
            return name
        }
        return "—"
    }
}

// MARK: - 列表行用小字地址

struct AsyncAddressCaption: View {
    let prefix: String
    let latitude: Double?
    let longitude: Double?

    @State private var text = "…"

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(prefix)
                .foregroundStyle(.tertiary)
            Text(text)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .font(.caption)
        .task(id: taskKey) {
            if latitude == nil || longitude == nil {
                text = "—"
                return
            }
            text = "…"
            text = await TripGeocodeCache.shared.address(latitude: latitude, longitude: longitude)
        }
    }

    private var taskKey: String {
        guard let la = latitude, let lo = longitude else { return "nil" }
        return String(format: "%.5f,%.5f", la, lo)
    }
}

// MARK: - 地址行

struct GeocodedAddressLine: View {
    let label: String
    let latitude: Double?
    let longitude: Double?

    @State private var resolved = "解析地址…"

    var body: some View {
        LabeledContent(label) {
            Text(resolved)
                .multilineTextAlignment(.trailing)
        }
        .task(id: taskKey) {
            if latitude == nil || longitude == nil {
                resolved = "—"
                return
            }
            resolved = "解析地址…"
            resolved = await TripGeocodeCache.shared.address(latitude: latitude, longitude: longitude)
        }
    }

    private var taskKey: String {
        guard let la = latitude, let lo = longitude else { return "nil" }
        return String(format: "%.5f,%.5f", la, lo)
    }
}
