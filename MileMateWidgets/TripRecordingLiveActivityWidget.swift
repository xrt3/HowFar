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
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(TripRecordingLiveActivityFormatting.distance(context.state.distanceMeters))
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                        Text("里程")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(TripRecordingLiveActivityFormatting.duration(context.state.elapsedSeconds))
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                        Text("记录时长")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("轨迹点 \(context.state.pointCount)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        if context.state.isPaused {
                            Button(intent: ResumeTripRecordingIntent()) {
                                Label("继续", systemImage: "play.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, minHeight: 40)
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button(intent: PauseTripRecordingIntent()) {
                                Label("暂停", systemImage: "pause.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, minHeight: 40)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.top, 4)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("MileMate")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if state.isPaused {
                    Text("已暂停")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: Capsule())
                }
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(TripRecordingLiveActivityFormatting.distance(state.distanceMeters))
                        .font(.headline)
                        .monospacedDigit()
                    Text("里程")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(TripRecordingLiveActivityFormatting.duration(state.elapsedSeconds))
                        .font(.headline)
                        .monospacedDigit()
                    Text("记录时长")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text("轨迹点 \(state.pointCount)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            HStack(spacing: 10) {
                if state.isPaused {
                    Button(intent: ResumeTripRecordingIntent()) {
                        Label("继续", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(intent: PauseTripRecordingIntent()) {
                        Label("暂停", systemImage: "pause.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}
