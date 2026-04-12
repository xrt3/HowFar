//
//  TripsListView.swift
//  MileMate
//

import SwiftData
import SwiftUI

struct TripsListView: View {
    @Query(sort: \Trip.startedAt, order: .reverse) private var trips: [Trip]
    @State private var summaryURL: URL?
    @State private var showShareSummary = false

    var body: some View {
        List {
            Section {
                Button {
                    exportAllSummary()
                } label: {
                    Label("导出全部摘要 CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(trips.isEmpty)
            }

            ForEach(trips) { trip in
                NavigationLink(value: trip) {
                    TripRowView(trip: trip)
                }
            }
        }
        .navigationTitle("行程记录")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: Trip.self) { trip in
            TripDetailView(trip: trip)
        }
        .sheet(isPresented: $showShareSummary) {
            if let summaryURL {
                ActivityView(activityItems: [summaryURL])
            }
        }
    }

    private func exportAllSummary() {
        let data = CSVExport.tripsSummaryCSV(trips: trips)
        let name = "MileMate-行程摘要-\(fileStamp()).csv"
        guard let url = try? CSVExport.writeTemporaryFile(data: data, name: name) else { return }
        summaryURL = url
        showShareSummary = true
    }

    private func fileStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }
}

private struct TripRowView: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(trip.startedAt.formatted(date: .abbreviated, time: .shortened))
                if trip.endedAt == nil {
                    Text("进行中")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
            }
            Text(String(format: "%.2f 公里", trip.totalDistanceMeters / 1000))
                .font(.headline)
        }
    }
}
