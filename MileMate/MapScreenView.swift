//
//  MapScreenView.swift
//  MileMate
//

import MapKit
import SwiftData
import SwiftUI
import UIKit

struct MapScreenView: View {
    /// 底栏 idle 状态左右圆形按钮边长；主按钮与之对齐以形成同一视觉行高。
    private static let mapChromeControlSide: CGFloat = 52

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var locationService: LocationTrackingService

    @State private var showTrips = false
    @State private var showLocationDeniedAlert = false
    @State private var showAlwaysAuthHint = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $locationService.mapPosition) {
                UserAnnotation()
                if locationService.routeCoordinates.count >= 2 {
                    MapPolyline(coordinates: locationService.routeCoordinates)
                        .stroke(Color.accentColor, lineWidth: 5)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapCompass()
            }

            bottomBar
                .padding(.horizontal, locationService.isRecording ? 0 : 20)
                .padding(.bottom, locationService.isRecording ? 0 : 8)
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            locationService.modelContext = modelContext
            locationService.refreshAuthorizationStatus()
            locationService.resumeIncompleteTrip()
        }
        .sheet(isPresented: $showTrips) {
            NavigationStack {
                TripsListView()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
            .presentationCornerRadius(24)
        }
        .alert("需要定位权限", isPresented: $showLocationDeniedAlert) {
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("请在设置中允许 MileMate 使用定位，以便记录行车轨迹与里程。")
        }
        .alert("后台记录", isPresented: $showAlwaysAuthHint) {
            Button("请求「始终」") {
                locationService.requestAlwaysUpgrade()
            }
            Button("仍要开始", role: .none) {
                attemptStartTrip()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("锁屏或切换到其他应用时若要持续记录，请在下一步选择「始终允许」定位。")
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        Group {
            if locationService.isRecording {
                recordingBottomSheet
                    .transition(bottomChromeTransition)
            } else {
                idleBottomBar
                    .transition(bottomChromeTransition)
            }
        }
    }

    /// 底栏切换：插入时轻微上移 + 淡入，移除时仅淡出，避免双重大幅位移动画（更贴近系统面板节奏）。
    private var bottomChromeTransition: AnyTransition {
        .asymmetric(
            insertion: .offset(y: 20).combined(with: .opacity),
            removal: .opacity
        )
    }

    private var idleBottomBar: some View {
        HStack(spacing: 12) {
            tripsListButton
            startTripButton
            recenterButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
            }
        }
    }

    private var recordingBottomSheet: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(.secondary.opacity(0.35))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 6)

            VStack(spacing: 16) {
                HStack {
                    tripsListButton
                    Spacer(minLength: 0)
                }

                if locationService.activeTripStartedAt != nil {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let elapsed = locationService.activeRecordingElapsed(at: context.date)
                        HStack(alignment: .top, spacing: 16) {
                            recordingStatBlock(
                                primary: recordingElapsedPrimary(elapsed),
                                caption: locationService.isRecordingPaused ? "记录时长（已暂停）" : "记录时长",
                                alignTrailing: false
                            )
                            recordingStatBlock(
                                primary: recordingDistancePrimary(locationService.totalDistanceMeters),
                                caption: "已过里程",
                                alignTrailing: true
                            )
                        }
                    }
                }

                HStack(spacing: 12) {
                    pauseOrResumeButton
                        .frame(maxWidth: .infinity)
                    endTripButton
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity)
        .background {
            RecordingSheetBackground()
        }
    }

    private func recordingStatBlock(primary: (String, String), caption: String, alignTrailing: Bool) -> some View {
        let stackAlign: HorizontalAlignment = alignTrailing ? .trailing : .leading
        return VStack(alignment: stackAlign, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(primary.0)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                if !primary.1.isEmpty {
                    Text(primary.1)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            Text(caption)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: alignTrailing ? .trailing : .leading)
    }

    /// 已过时间：仅按分钟递进（不显示秒），满一小时为 H:MM。
    private func recordingElapsedPrimary(_ interval: TimeInterval) -> (String, String) {
        let t = max(0, interval)
        let wholeMinutes = Int(t / 60)
        if t < 3600 {
            if wholeMinutes < 1 {
                return ("未满 1", "分钟")
            }
            return ("\(wholeMinutes)", "分钟")
        }
        let hours = Int(t) / 3600
        let minutes = (Int(t) % 3600) / 60
        return ("\(hours):\(String(format: "%02d", minutes))", "")
    }

    private func recordingDistancePrimary(_ meters: Double) -> (String, String) {
        let m = max(0, meters)
        if m < 1000 {
            return ("\(Int(m.rounded()))", "米")
        }
        return (String(format: "%.1f", m / 1000), "公里")
    }

    private var tripsListButton: some View {
        Button {
            showTrips = true
        } label: {
            Image(systemName: "list.bullet")
                .font(.title2)
                .frame(width: Self.mapChromeControlSide, height: Self.mapChromeControlSide)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .background(chromeCircleFill, in: Circle())
        .overlay {
            Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .contentShape(Circle())
    }

    private var recenterButton: some View {
        Button {
            handleRecenterTap()
        } label: {
            Image(systemName: "location.circle.fill")
                .font(.title2)
                .frame(width: Self.mapChromeControlSide, height: Self.mapChromeControlSide)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .background(chromeCircleFill, in: Circle())
        .overlay {
            Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .contentShape(Circle())
    }

    /// 与底栏毛玻璃区分的系统填充色（对应 HIG 中 secondary/tertiary system fill 层次）。
    private var chromeCircleFill: Color {
        Color(uiColor: .tertiarySystemFill)
    }

    private var startTripButton: some View {
        Button {
            handleStartTap()
        } label: {
            Label("开始行程", systemImage: "play.fill")
                .font(.headline)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: Self.mapChromeControlSide)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background(Color.accentColor, in: Capsule())
        .overlay {
            Capsule().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
        }
    }

    private var pauseOrResumeButton: some View {
        Group {
            if locationService.isRecordingPaused {
                Button {
                    locationService.resumeRecording()
                } label: {
                    Label("继续", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .background(.regularMaterial, in: Capsule())
            } else {
                Button {
                    locationService.pauseRecording()
                } label: {
                    Label("暂停", systemImage: "pause.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .background(.regularMaterial, in: Capsule())
            }
        }
        .contentShape(Capsule())
    }

    private var endTripButton: some View {
        Button(role: .destructive) {
            locationService.endTrip()
        } label: {
            Label("结束", systemImage: "stop.fill")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 52)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule().strokeBorder(Color.red.opacity(0.45), lineWidth: 1)
                }
        }
        .contentShape(Capsule())
    }

    private func handleRecenterTap() {
        switch locationService.authorizationStatus {
        case .denied, .restricted:
            showLocationDeniedAlert = true
        case .notDetermined:
            locationService.requestWhenInUse()
        default:
            locationService.recenterMapOnUserLocation()
        }
    }

    private func handleStartTap() {
        switch locationService.authorizationStatus {
        case .notDetermined:
            locationService.requestWhenInUse()
        case .denied, .restricted:
            showLocationDeniedAlert = true
        case .authorizedWhenInUse:
            showAlwaysAuthHint = true
        case .authorizedAlways:
            attemptStartTrip()
        @unknown default:
            locationService.requestWhenInUse()
        }
    }

    private func attemptStartTrip() {
        do {
            try locationService.startTrip()
        } catch {
            // SwiftData 保存失败时静默；调试可打印
        }
    }
}

// MARK: - 录制中底部毛玻璃底板（与地图分离，避免统计文字与路网叠色）

private struct RecordingSheetBackground: View {
    var body: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 22,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 22,
            style: .continuous
        )
        .fill(.regularMaterial)
        .shadow(color: .black.opacity(0.1), radius: 20, y: -4)
        .ignoresSafeArea(edges: .bottom)
    }
}
