//
//  TripDetailView.swift
//  MileMate
//

import MapKit
import SwiftData
import SwiftUI

struct TripDetailView: View {
    @Bindable var trip: Trip

    @State private var camera: MapCameraPosition = .automatic
    @State private var shareURL: URL?
    @State private var shareTrackURL: URL?
    @State private var showShareSummary = false
    @State private var showShareTrack = false

    private var coordinates: [CLLocationCoordinate2D] {
        trip.points
            .sorted { $0.timestamp < $1.timestamp }
            .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    private var endpointCoords: (startLat: Double?, startLon: Double?, endLat: Double?, endLon: Double?) {
        trip.resolvedEndpointLatLon()
    }

    var body: some View {
        GeometryReader { geo in
            let mapHeight = min(max(geo.size.height * 0.5, 260), 420)
            VStack(spacing: 0) {
                Map(position: $camera) {
                    if coordinates.count >= 2 {
                        MapPolyline(coordinates: coordinates)
                            .stroke(Color.accentColor, lineWidth: 4)
                    } else if let c = coordinates.first {
                        Marker("起点", coordinate: c)
                    }
                }
                .mapStyle(.standard)
                .frame(height: mapHeight)
                .clipShape(RoundedRectangle(cornerRadius: 0))
                .onAppear { fitMap() }
                .onChange(of: coordinates.count) { _, _ in fitMap() }

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        detailCard(title: "行程信息") {
                            GeocodedAddressLine(
                                label: "起点",
                                latitude: endpointCoords.startLat,
                                longitude: endpointCoords.startLon
                            )
                            GeocodedAddressLine(
                                label: "终点",
                                latitude: endpointCoords.endLat,
                                longitude: endpointCoords.endLon
                            )
                            LabeledContent("里程") {
                                Text(String(format: "%.2f 公里", trip.totalDistanceMeters / 1000))
                            }
                            LabeledContent("开始时间") {
                                Text(trip.startedAt.formatted(date: .abbreviated, time: .shortened))
                            }
                            if let ended = trip.endedAt {
                                LabeledContent("结束时间") {
                                    Text(ended.formatted(date: .abbreviated, time: .shortened))
                                }
                            } else {
                                LabeledContent("状态") {
                                    Text("进行中")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if let note = trip.note, !note.isEmpty {
                                LabeledContent("备注") {
                                    Text(note)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
                .frame(maxWidth: .infinity)
                .background(.quaternary.opacity(0.35))
            }
        }
        .navigationTitle("行程详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        shareSingleSummary()
                    } label: {
                        Label("导出本条摘要 CSV", systemImage: "doc.text")
                    }
                    Button {
                        shareTrack()
                    } label: {
                        Label("导出轨迹点 CSV", systemImage: "map")
                    }
                    .disabled(coordinates.isEmpty)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showShareSummary) {
            if let shareURL {
                ActivityView(activityItems: [shareURL])
            }
        }
        .sheet(isPresented: $showShareTrack) {
            if let shareTrackURL {
                ActivityView(activityItems: [shareTrackURL])
            }
        }
    }

    @ViewBuilder
    private func detailCard(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.background)
            }
        }
    }

    private func fitMap() {
        guard !coordinates.isEmpty else {
            camera = .automatic
            return
        }
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.01),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.01)
        )
        camera = .region(MKCoordinateRegion(center: center, span: span))
    }

    private func shareSingleSummary() {
        let data = CSVExport.tripsSummaryCSV(trips: [trip])
        let name = "MileMate-单条行程-\(fileStamp()).csv"
        guard let url = try? CSVExport.writeTemporaryFile(data: data, name: name) else { return }
        shareURL = url
        showShareSummary = true
    }

    private func shareTrack() {
        let data = CSVExport.tripTrackCSV(trip: trip)
        let name = "MileMate-轨迹-\(fileStamp()).csv"
        guard let url = try? CSVExport.writeTemporaryFile(data: data, name: name) else { return }
        shareTrackURL = url
        showShareTrack = true
    }

    private func fileStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }
}
