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

    @Relationship(deleteRule: .cascade, inverse: \TripPoint.trip)
    var points: [TripPoint]

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date? = nil,
        totalDistanceMeters: Double = 0,
        note: String? = nil,
        points: [TripPoint] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.totalDistanceMeters = totalDistanceMeters
        self.note = note
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
