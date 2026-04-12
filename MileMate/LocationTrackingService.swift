//
//  LocationTrackingService.swift
//  MileMate
//

import Combine
import CoreLocation
import Foundation
import MapKit
import SwiftData
import SwiftUI

@MainActor
final class LocationTrackingService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var isRecording = false
    @Published private(set) var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published private(set) var totalDistanceMeters: Double = 0
    /// 与 `Map(position:)` 双向绑定；用户拖动地图时会写入。
    @Published var mapPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    /// 由视图在 `onAppear` 中注入，供定位回调写入 SwiftData
    weak var modelContext: ModelContext?

    private let manager = CLLocationManager()
    private var currentTrip: Trip?
    private var lastRecordedLocation: CLLocation?

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.activityType = .automotiveNavigation
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 5
        manager.pausesLocationUpdatesAutomatically = false
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = manager.authorizationStatus
    }

    func requestWhenInUse() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysUpgrade() {
        manager.requestAlwaysAuthorization()
    }

    private func applyBackgroundUpdatesIfAllowed() {
        let status = manager.authorizationStatus
        let always = status == .authorizedAlways
        manager.allowsBackgroundLocationUpdates = always
        manager.showsBackgroundLocationIndicator = always
    }

    /// 恢复未结束的行程（App 重启后）
    func resumeIncompleteTrip() {
        guard let modelContext else { return }
        if isRecording { return }
        let descriptor = FetchDescriptor<Trip>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        guard let trip = try? modelContext.fetch(descriptor).first else { return }
        currentTrip = trip
        isRecording = true
        totalDistanceMeters = trip.totalDistanceMeters
        routeCoordinates = trip.points
            .sorted { $0.timestamp < $1.timestamp }
            .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        if let lastCoord = routeCoordinates.last {
            lastRecordedLocation = CLLocation(
                latitude: lastCoord.latitude,
                longitude: lastCoord.longitude
            )
        }
        applyBackgroundUpdatesIfAllowed()
        manager.startUpdatingLocation()
    }

    func startTrip() throws {
        guard let modelContext else { return }
        guard !isRecording else { return }
        applyBackgroundUpdatesIfAllowed()
        let trip = Trip(startedAt: Date())
        modelContext.insert(trip)
        try modelContext.save()
        currentTrip = trip
        isRecording = true
        routeCoordinates = []
        totalDistanceMeters = 0
        lastRecordedLocation = nil
        manager.startUpdatingLocation()
    }

    func endTrip() {
        guard let modelContext else { return }
        guard isRecording, let trip = currentTrip else { return }
        manager.stopUpdatingLocation()
        trip.endedAt = Date()
        trip.totalDistanceMeters = totalDistanceMeters
        currentTrip = nil
        isRecording = false
        lastRecordedLocation = nil
        mapPosition = .userLocation(fallback: .automatic)
        try? modelContext.save()
    }

    private func appendLocation(_ location: CLLocation) {
        guard let modelContext, let trip = currentTrip else { return }
        if location.horizontalAccuracy > 80 { return }
        if location.speed >= 0, location.speed < 0.5 {
            let d = lastRecordedLocation?.distance(from: location) ?? .infinity
            if d < 8 { return }
        }

        if let prev = lastRecordedLocation {
            totalDistanceMeters += location.distance(from: prev)
        }
        lastRecordedLocation = location

        let coord = location.coordinate
        routeCoordinates.append(coord)

        let point = TripPoint(
            timestamp: location.timestamp,
            latitude: coord.latitude,
            longitude: coord.longitude,
            horizontalAccuracy: location.horizontalAccuracy,
            trip: trip
        )
        modelContext.insert(point)
        trip.totalDistanceMeters = totalDistanceMeters
        try? modelContext.save()

        mapPosition = .region(
            MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        )
    }
}

extension LocationTrackingService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            self.applyBackgroundUpdatesIfAllowed()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            guard self.isRecording else { return }
            self.appendLocation(loc)
        }
    }
}
