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

    var body: some View {
        List {
            Section("摘要") {
                LabeledContent("开始") {
                    Text(trip.startedAt.formatted(date: .abbreviated, time: .shortened))
                }
                if let ended = trip.endedAt {
                    LabeledContent("结束") {
                        Text(ended.formatted(date: .abbreviated, time: .shortened))
                    }
                }
                LabeledContent("里程") {
                    Text(String(format: "%.2f 公里", trip.totalDistanceMeters / 1000))
                }
                if let note = trip.note, !note.isEmpty {
                    LabeledContent("备注") {
                        Text(note)
                    }
                }
            }

            Section {
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
            }

            Section("地图") {
                Map(position: $camera) {
                    if coordinates.count >= 2 {
                        MapPolyline(coordinates: coordinates)
                            .stroke(Color.accentColor, lineWidth: 4)
                    } else if let c = coordinates.first {
                        Marker("起点", coordinate: c)
                    }
                }
                .mapStyle(.standard)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .navigationTitle("行程详情")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fitMap()
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
