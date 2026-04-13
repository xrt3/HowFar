//
//  TripModels.swift
//  MileMate
//

import Foundation
import SwiftData

@Model
final class Trip {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var totalDistanceMeters: Double
    var note: String?
    /// 列表与逆地理用，避免加载全部轨迹点；由 `LocationTrackingService` 写入。
    var startLatitude: Double?
    var startLongitude: Double?
    var endLatitude: Double?
    var endLongitude: Double?
    /// 已归档行程不出现在主列表。使用 `Bool?` 以便旧版数据库迁移时该列可为 NULL（`nil`/`false` 均视为未归档）。
    var isArchived: Bool?
    /// 已累计的暂停时长（秒），不含当前这一段暂停。
    var totalRecordingPauseSeconds: Double
    /// 非 `nil` 表示当前处于暂停中（持久化，便于 App 被杀死后恢复）。
    var recordingPausedSince: Date?

    @Relationship(deleteRule: .cascade, inverse: \TripPoint.trip)
    var points: [TripPoint]

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date? = nil,
        totalDistanceMeters: Double = 0,
        note: String? = nil,
        startLatitude: Double? = nil,
        startLongitude: Double? = nil,
        endLatitude: Double? = nil,
        endLongitude: Double? = nil,
        isArchived: Bool? = nil,
        totalRecordingPauseSeconds: Double = 0,
        recordingPausedSince: Date? = nil,
        points: [TripPoint] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.totalDistanceMeters = totalDistanceMeters
        self.note = note
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.endLatitude = endLatitude
        self.endLongitude = endLongitude
        self.isArchived = isArchived
        self.totalRecordingPauseSeconds = totalRecordingPauseSeconds
        self.recordingPausedSince = recordingPausedSince
        self.points = points
    }
}

@Model
final class TripPoint {
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var horizontalAccuracy: Double
    var trip: Trip?

    init(
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        horizontalAccuracy: Double,
        trip: Trip? = nil
    ) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
        self.trip = trip
    }
}
