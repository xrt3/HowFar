//
//  LocationTrackingService.swift
//  MileMate
//

import Combine
import CoreLocation
import Foundation
import MapKit
import MileMateLiveActivityAttributes
import SwiftData
import SwiftUI
import UIKit

@MainActor
final class LocationTrackingService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var isRecording = false
    /// 录制中且已暂停（不采点、不更新定位以省电）；与 `Trip.recordingPausedSince` 同步。
    @Published private(set) var isRecordingPaused = false
    @Published private(set) var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published private(set) var totalDistanceMeters: Double = 0
    /// 当前录制中行程的开始时间（用于界面显示已过时间）；非录制时为 `nil`。
    @Published private(set) var activeTripStartedAt: Date?
    /// 与 `Map(position:)` 双向绑定；用户拖动地图时会写入。
    @Published var mapPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    /// 由视图在 `onAppear` 中注入，供定位回调写入 SwiftData
    weak var modelContext: ModelContext?

    private let manager = CLLocationManager()
    private var currentTrip: Trip?
    private var lastRecordedLocation: CLLocation?
    private var cancellables = Set<AnyCancellable>()
    private var liveActivityHeartbeat: AnyCancellable?
    /// 非录制时用于省电的移动阈值（米）；录制中改为 `kCLDistanceFilterNone`，否则静止几秒可能收不到任何定位更新、行程无点。
    private static let idleDistanceFilter: CLLocationDistance = 5
    /// 与 `MapScreenView` 底栏切换一致：优先 `smooth`（系统常用节奏）；「减少动态效果」时用短线性过渡。
    private static var mapBottomChromeAnimation: Animation {
        UIAccessibility.isReduceMotionEnabled
            ? .linear(duration: 0.18)
            : .smooth(duration: 0.32)
    }

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.activityType = .automotiveNavigation
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = Self.idleDistanceFilter
        manager.pausesLocationUpdatesAutomatically = false

        NotificationCenter.default.publisher(for: .mileMatePauseTripRecording)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.pauseRecording()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .mileMateResumeTripRecording)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.resumeRecording()
            }
            .store(in: &cancellables)
    }

    /// 有效记录时长（扣除暂停时段），用于界面与 Live Activity。
    func activeRecordingElapsed(at date: Date) -> TimeInterval {
        guard let trip = currentTrip, let started = activeTripStartedAt else { return 0 }
        let wall = date.timeIntervalSince(started)
        var pauseTotal = trip.totalRecordingPauseSeconds
        if let since = trip.recordingPausedSince {
            pauseTotal += date.timeIntervalSince(since)
        }
        return max(0, wall - pauseTotal)
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
        isRecordingPaused = trip.recordingPausedSince != nil
        totalDistanceMeters = trip.totalDistanceMeters
        activeTripStartedAt = trip.startedAt
        routeCoordinates = trip.points
            .sorted { $0.timestamp < $1.timestamp }
            .map { MapCoordinateAlignment.displayCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
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
        mapPosition = .userLocation(fallback: .automatic)
        if isRecordingPaused {
            manager.stopUpdatingLocation()
            manager.distanceFilter = Self.idleDistanceFilter
            Task {
                await TripLiveActivityCoordinator.beginIfPossible(tripId: trip.id, service: self)
                await TripLiveActivityCoordinator.pushUpdate(from: self, force: true)
            }
        } else {
            manager.distanceFilter = kCLDistanceFilterNone
            manager.startUpdatingLocation()
            Task {
                await TripLiveActivityCoordinator.beginIfPossible(tripId: trip.id, service: self)
                await TripLiveActivityCoordinator.pushUpdate(from: self, force: true)
            }
            startLiveActivityHeartbeat()
        }
    }

    func startTrip() throws {
        guard let modelContext else { return }
        guard !isRecording else { return }
        applyBackgroundUpdatesIfAllowed()
        let trip = Trip(startedAt: Date())
        modelContext.insert(trip)
        try modelContext.save()
        currentTrip = trip
        withAnimation(Self.mapBottomChromeAnimation) {
            isRecording = true
            isRecordingPaused = false
            activeTripStartedAt = trip.startedAt
            routeCoordinates = []
            totalDistanceMeters = 0
            lastRecordedLocation = nil
            mapPosition = .userLocation(fallback: .automatic)
        }
        manager.distanceFilter = kCLDistanceFilterNone
        manager.startUpdatingLocation()
        Task {
            await TripLiveActivityCoordinator.beginIfPossible(tripId: trip.id, service: self)
            await TripLiveActivityCoordinator.pushUpdate(from: self, force: true)
        }
        startLiveActivityHeartbeat()
    }

    func endTrip() {
        guard let modelContext else { return }
        guard isRecording, let trip = currentTrip else { return }
        // 结束前若尚无轨迹点（静止/精度过滤/刚点结束），用当前已知位置写一条快照，避免「行程消失」
        if trip.points.isEmpty {
            ingestSnapshotIfNeeded(location: manager.location, trip: trip, modelContext: modelContext)
        }
        manager.stopUpdatingLocation()
        manager.distanceFilter = Self.idleDistanceFilter
        if let since = trip.recordingPausedSince {
            trip.totalRecordingPauseSeconds += Date().timeIntervalSince(since)
            trip.recordingPausedSince = nil
        }
        trip.endedAt = Date()
        trip.totalDistanceMeters = totalDistanceMeters
        withAnimation(Self.mapBottomChromeAnimation) {
            currentTrip = nil
            isRecording = false
            isRecordingPaused = false
            activeTripStartedAt = nil
            lastRecordedLocation = nil
            mapPosition = .userLocation(fallback: .automatic)
        }
        stopLiveActivityHeartbeat()
        try? modelContext.save()
        Task {
            await TripLiveActivityCoordinator.endIfNeeded()
        }
    }

    func pauseRecording() {
        guard let modelContext, let trip = currentTrip, isRecording else { return }
        guard !isRecordingPaused else { return }
        trip.recordingPausedSince = Date()
        isRecordingPaused = true
        try? modelContext.save()
        manager.stopUpdatingLocation()
        manager.distanceFilter = Self.idleDistanceFilter
        stopLiveActivityHeartbeat()
        Task {
            await TripLiveActivityCoordinator.pushUpdate(from: self, force: true)
        }
    }

    func resumeRecording() {
        guard let modelContext, let trip = currentTrip, isRecording else { return }
        guard isRecordingPaused, let since = trip.recordingPausedSince else { return }
        trip.totalRecordingPauseSeconds += Date().timeIntervalSince(since)
        trip.recordingPausedSince = nil
        isRecordingPaused = false
        try? modelContext.save()
        applyBackgroundUpdatesIfAllowed()
        manager.distanceFilter = kCLDistanceFilterNone
        manager.startUpdatingLocation()
        startLiveActivityHeartbeat()
        Task {
            await TripLiveActivityCoordinator.pushUpdate(from: self, force: true)
        }
    }

    private func startLiveActivityHeartbeat() {
        stopLiveActivityHeartbeat()
        liveActivityHeartbeat = Timer.publish(every: 4, tolerance: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                Task {
                    await TripLiveActivityCoordinator.pushUpdate(from: self, force: false)
                }
            }
    }

    private func stopLiveActivityHeartbeat() {
        liveActivityHeartbeat?.cancel()
        liveActivityHeartbeat = nil
    }

    /// 结束行程时补一条点；精度阈值略放宽，避免室内/首点被拒后整段空白。
    private func ingestSnapshotIfNeeded(location: CLLocation?, trip: Trip, modelContext: ModelContext) {
        guard let location, location.horizontalAccuracy > 0, location.horizontalAccuracy <= 200 else { return }
        let rawCoord = location.coordinate
        let mapCoord = MapCoordinateAlignment.displayCoordinate(rawCoord)
        routeCoordinates.append(mapCoord)
        lastRecordedLocation = location
        let point = TripPoint(
            timestamp: location.timestamp,
            latitude: rawCoord.latitude,
            longitude: rawCoord.longitude,
            horizontalAccuracy: location.horizontalAccuracy,
            trip: trip
        )
        modelContext.insert(point)
        trip.totalDistanceMeters = totalDistanceMeters
        trip.startLatitude = rawCoord.latitude
        trip.startLongitude = rawCoord.longitude
        trip.endLatitude = rawCoord.latitude
        trip.endLongitude = rawCoord.longitude
        try? modelContext.save()
    }

    private func appendLocation(_ location: CLLocation) {
        guard !isRecordingPaused else { return }
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

        let rawCoord = location.coordinate
        let mapCoord = MapCoordinateAlignment.displayCoordinate(rawCoord)
        routeCoordinates.append(mapCoord)

        let point = TripPoint(
            timestamp: location.timestamp,
            latitude: rawCoord.latitude,
            longitude: rawCoord.longitude,
            horizontalAccuracy: location.horizontalAccuracy,
            trip: trip
        )
        modelContext.insert(point)
        trip.totalDistanceMeters = totalDistanceMeters
        if trip.startLatitude == nil {
            trip.startLatitude = rawCoord.latitude
            trip.startLongitude = rawCoord.longitude
        }
        trip.endLatitude = rawCoord.latitude
        trip.endLongitude = rawCoord.longitude
        try? modelContext.save()
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
            guard self.isRecording, !self.isRecordingPaused else { return }
            self.appendLocation(loc)
        }
    }
}
