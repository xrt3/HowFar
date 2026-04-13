import Foundation

public extension Notification.Name {
    /// 由 Live Activity / App Intent 发送，主应用内暂停记录。
    static let mileMatePauseTripRecording = Notification.Name("RuitongFuture.MileMate.pauseTripRecording")
    /// 由 Live Activity / App Intent 发送，主应用内继续记录。
    static let mileMateResumeTripRecording = Notification.Name("RuitongFuture.MileMate.resumeTripRecording")
}
