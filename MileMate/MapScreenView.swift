//
//  MapScreenView.swift
//  MileMate
//

import MapKit
import SwiftData
import SwiftUI
import UIKit

struct MapScreenView: View {
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
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
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
        GlassEffectContainer(spacing: 12) {
            if locationService.isRecording {
                Text(String(format: "已记录 %.2f 公里", locationService.totalDistanceMeters / 1000))
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            HStack(spacing: 12) {
                Button {
                    showTrips = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.title2)
                        .frame(width: 52, height: 52)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())

                Button {
                    handleRecenterTap()
                } label: {
                    Image(systemName: "location.north.line.fill")
                        .font(.title2)
                        .frame(width: 52, height: 52)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())

                if locationService.isRecording {
                    Button(role: .destructive) {
                        locationService.endTrip()
                    } label: {
                        Label("结束行程", systemImage: "stop.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(.red).interactive(), in: Capsule())
                } else {
                    Button {
                        handleStartTap()
                    } label: {
                        Label("开始行程", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
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
