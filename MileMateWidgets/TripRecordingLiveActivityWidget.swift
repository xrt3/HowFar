//
//  TripRecordingLiveActivityWidget.swift
//  MileMateWidgets
//

import AppIntents
import MileMateLiveActivityAttributes
import SwiftUI
import WidgetKit

struct TripRecordingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripRecordingActivityAttributes.self) { context in
            TripRecordingLockBannerView(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    HStack {
                        Spacer(minLength: 0)
                        VStack(spacing: 10) {
                            HStack(spacing: 14) {
                                statPill(
                                    value: TripRecordingLiveActivityFormatting.distance(context.state.distanceMeters),
                                    caption: "里程"
                                )
                                statPill(
                                    value: TripRecordingLiveActivityFormatting.duration(context.state.elapsedSeconds),
                                    caption: "记录时长"
                                )
                            }

                            Text("轨迹点 \(context.state.pointCount)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 12) {
                                if context.state.isPaused {
                                    Button(intent: ResumeTripRecordingIntent()) {
                                        Label("继续", systemImage: "play.fill")
                                            .font(.headline)
                                            .frame(maxWidth: .infinity, minHeight: 38)
                                    }
                                    .buttonStyle(.borderedProminent)
                                } else {
                                    Button(intent: PauseTripRecordingIntent()) {
                                        Label("暂停", systemImage: "pause.fill")
                                            .font(.headline)
                                            .frame(maxWidth: .infinity, minHeight: 38)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                        .padding(.horizontal, 6)
                        .frame(maxWidth: 340)
                        Spacer(minLength: 0)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.circle.fill" : "location.fill")
            } compactTrailing: {
                Text(TripRecordingLiveActivityFormatting.distanceShort(context.state.distanceMeters))
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "map")
            }
        }
    }

}

private func statPill(value: String, caption: String) -> some View {
    VStack(alignment: .center, spacing: 2) {
        Text(value)
            .font(.title3.weight(.semibold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        Text(caption)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
}

private enum TripRecordingLiveActivityFormatting {
    static func distance(_ meters: Double) -> String {
        let m = max(0, meters)
        if m < 1000 {
            return "\(Int(m.rounded())) 米"
        }
        return String(format: "%.1f 公里", m / 1000)
    }

    static func distanceShort(_ meters: Double) -> String {
        let m = max(0, meters)
        if m < 1000 {
            return "\(Int(m.rounded()))m"
        }
        return String(format: "%.1fkm", m / 1000)
    }

    static func duration(_ seconds: Int) -> String {
        let s = max(0, seconds)
        if s < 3600 {
            let m = s / 60
            if m < 1 { return "<1 分钟" }
            return "\(m) 分钟"
        }
        let h = s / 3600
        let m = (s % 3600) / 60
        return "\(h):\(String(format: "%02d", m))"
    }
}

private struct TripRecordingLockBannerView: View {
    let state: TripRecordingActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                Text("MileMate")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if state.isPaused {
                    Text("已暂停")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.quaternary, in: Capsule())
                }
            }

            HStack(spacing: 14) {
                lockStatPill(
                    value: TripRecordingLiveActivityFormatting.distance(state.distanceMeters),
                    caption: "里程"
                )
                lockStatPill(
                    value: TripRecordingLiveActivityFormatting.duration(state.elapsedSeconds),
                    caption: "记录时长"
                )
            }

            Text("轨迹点 \(state.pointCount)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                if state.isPaused {
                    Button(intent: ResumeTripRecordingIntent()) {
                        Label("继续", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(intent: PauseTripRecordingIntent()) {
                        Label("暂停", systemImage: "pause.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private func lockStatPill(value: String, caption: String) -> some View {
    VStack(spacing: 3) {
        Text(value)
            .font(.headline)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        Text(caption)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
}
