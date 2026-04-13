//
//  TripRecordingIntents.swift
//  MileMateWidgets
//

import AppIntents
import Foundation
import MileMateLiveActivityAttributes

/// 需唤起主应用进程以更新定位与 SwiftData；由系统先拉起 App 再执行。
struct PauseTripRecordingIntent: AppIntent {
    static var title: LocalizedStringResource { "暂停记录" }
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .mileMatePauseTripRecording, object: nil)
        }
        return .result()
    }
}

struct ResumeTripRecordingIntent: AppIntent {
    static var title: LocalizedStringResource { "继续记录" }
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .mileMateResumeTripRecording, object: nil)
        }
        return .result()
    }
}
