//
//  TripLiveActivityCoordinator.swift
//  MileMate
//

import ActivityKit
import Foundation
import MileMateLiveActivityAttributes

@MainActor
enum TripLiveActivityCoordinator {
    private static var currentActivity: Activity<TripRecordingActivityAttributes>?
    private static var lastPushedSignature: (Int, Int, Bool)?

    static func beginIfPossible(tripId: UUID, service: LocationTrackingService) async {
        await endIfNeeded()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = contentState(from: service)
        let attributes = TripRecordingActivityAttributes(tripId: tripId)
        let content = ActivityContent(state: state, staleDate: nil)
        do {
            currentActivity = try Activity.request(attributes: attributes, content: content, pushType: nil)
            lastPushedSignature = signature(from: state)
        } catch {
            currentActivity = nil
            lastPushedSignature = nil
        }
    }

    static func endIfNeeded() async {
        guard let activity = currentActivity else { return }
        let final = activity.content.state
        let content = ActivityContent(state: final, staleDate: nil)
        await activity.end(content, dismissalPolicy: .immediate)
        currentActivity = nil
        lastPushedSignature = nil
    }

    /// 有变化或强制刷新时推送；`force` 用于暂停/继续等需要立刻反馈的场景。
    static func pushUpdate(from service: LocationTrackingService, force: Bool = false) async {
        guard let activity = currentActivity, service.isRecording else { return }
        let state = contentState(from: service)
        let sig = signature(from: state)
        if !force, let last = lastPushedSignature, last == sig { return }
        lastPushedSignature = sig
        let content = ActivityContent(state: state, staleDate: nil)
        await activity.update(content)
    }

    private static func contentState(from service: LocationTrackingService) -> TripRecordingActivityAttributes.ContentState {
        let elapsed = Int(service.activeRecordingElapsed(at: Date()).rounded(.down))
        let points = service.routeCoordinates.count
        return TripRecordingActivityAttributes.ContentState(
            distanceMeters: service.totalDistanceMeters,
            pointCount: points,
            elapsedSeconds: max(0, elapsed),
            isPaused: service.isRecordingPaused
        )
    }

    private static func signature(from state: TripRecordingActivityAttributes.ContentState) -> (Int, Int, Bool) {
        let distanceBucket = Int(state.distanceMeters / 25)
        return (distanceBucket, state.elapsedSeconds, state.isPaused)
    }
}
