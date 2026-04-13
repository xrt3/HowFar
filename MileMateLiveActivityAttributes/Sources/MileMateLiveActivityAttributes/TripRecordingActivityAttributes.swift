import ActivityKit
import Foundation

/// App 与 Widget Extension 共用的 Live Activity 类型，需保持模块一致以便系统匹配。
public struct TripRecordingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var distanceMeters: Double
        public var pointCount: Int
        public var elapsedSeconds: Int
        public var isPaused: Bool

        public init(distanceMeters: Double, pointCount: Int, elapsedSeconds: Int, isPaused: Bool) {
            self.distanceMeters = distanceMeters
            self.pointCount = pointCount
            self.elapsedSeconds = elapsedSeconds
            self.isPaused = isPaused
        }
    }

    public var tripId: UUID

    public init(tripId: UUID) {
        self.tripId = tripId
    }
}
