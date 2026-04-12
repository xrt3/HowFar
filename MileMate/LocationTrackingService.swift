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

    /// 将地图相机切回跟随当前位置（替代系统地图控件里的定位按钮）。
    func recenterMapOnUserLocation() {
        mapPosition = .userLocation(fallback: .automatic)
    }

    /// `allowsBackgroundLocationUpdates` 仅在 Info.plist 的 `UIBackgroundModes` 含 `location` 且进程可被 Core Location 视为可后台时才能为 `true`，否则会触发 `NSInternalInconsistencyException`。模拟器常不满足后者，故在模拟器上保持关闭。
    private static var hasDeclaredBackgroundLocationMode: Bool {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") else { return false }
        if let modes = raw as? [String] {
            return modes.contains("location")
        }
        if let modes = raw as? [Any] {
            return modes.contains { ($0 as? String) == "location" }
        }
        if let single = raw as? String {
            return single == "location"
        }
        return false
    }

    private func shouldEnableBackgroundLocationUpdates(isAlwaysAuthorized: Bool) -> Bool {
        guard isAlwaysAuthorized else { return false }
        #if targetEnvironment(simulator)
        return false
        #else
        return Self.hasDeclaredBackgroundLocationMode
        #endif
    }

    private func applyBackgroundUpdatesIfAllowed() {
        let status = manager.authorizationStatus
        let always = status == .authorizedAlways
        let enable = shouldEnableBackgroundLocationUpdates(isAlwaysAuthorized: always)
        manager.allowsBackgroundLocationUpdates = enable
        manager.showsBackgroundLocationIndicator = enable
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
        if let first = routeCoordinates.first {
            if trip.startLatitude == nil {
                trip.startLatitude = first.latitude
                trip.startLongitude = first.longitude
            }
        }
        if let lastCoord = routeCoordinates.last {
            trip.endLatitude = lastCoord.latitude
            trip.endLongitude = lastCoord.longitude
            lastRecordedLocation = CLLocation(
                latitude: lastCoord.latitude,
                longitude: lastCoord.longitude
            )
        }
        try? modelContext.save()
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
        if trip.startLatitude == nil {
            trip.startLatitude = coord.latitude
            trip.startLongitude = coord.longitude
        }
        trip.endLatitude = coord.latitude
        trip.endLongitude = coord.longitude
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
            let previous = self.authorizationStatus
            self.authorizationStatus = manager.authorizationStatus
            self.applyBackgroundUpdatesIfAllowed()
            if previous == .notDetermined,
               manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways
            {
                MainlandLocalNetworkPermission.requestAfterFirstLocationGrantIfNeeded()
            }
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
