//
//  CSVExport.swift
//  MileMate
//

import Foundation

enum CSVExport {
    private static let utf8BOM = Data([0xEF, 0xBB, 0xBF])

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func tripsSummaryCSV(trips: [Trip]) -> Data {
        var lines = ["开始时间,结束时间,里程千米,时长秒,备注"]
        for trip in trips.sorted(by: { $0.startedAt > $1.startedAt }) {
            let start = isoFormatter.string(from: trip.startedAt)
            let end = trip.endedAt.map { isoFormatter.string(from: $0) } ?? ""
            let durationSec: String
            if let ended = trip.endedAt {
                durationSec = String(format: "%.0f", ended.timeIntervalSince(trip.startedAt))
            } else {
                durationSec = ""
            }
            let km = String(format: "%.3f", trip.totalDistanceMeters / 1000)
            let note = csvEscape(trip.note ?? "")
            lines.append("\(csvEscape(start)),\(csvEscape(end)),\(km),\(durationSec),\(note)")
        }
        let string = lines.joined(separator: "\n")
        let body = Data(string.utf8)
        return utf8BOM + body
    }

    static func tripTrackCSV(trip: Trip) -> Data {
        var lines = ["时间,纬度,经度,水平精度米"]
        let sorted = trip.points.sorted { $0.timestamp < $1.timestamp }
        for p in sorted {
            let t = isoFormatter.string(from: p.timestamp)
            let acc = String(format: "%.1f", p.horizontalAccuracy)
            lines.append("\(csvEscape(t)),\(p.latitude),\(p.longitude),\(acc)")
        }
        let string = lines.joined(separator: "\n")
        return utf8BOM + Data(string.utf8)
    }

    private static func csvEscape(_ s: String) -> String {
        let needsQuotes = s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r")
        let doubled = s.replacingOccurrences(of: "\"", with: "\"\"")
        if needsQuotes {
            return "\"\(doubled)\""
        }
        return doubled
    }

    static func writeTemporaryFile(data: Data, name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }
}
