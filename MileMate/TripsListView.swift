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

    private var monthSections: [MonthSection] {
        MonthSection.group(trips)
    }

    var body: some View {
        List {
            ForEach(monthSections) { section in
                Section {
                    ForEach(section.trips) { trip in
                        NavigationLink(value: trip) {
                            TripRowView(trip: trip)
                        }
                    }
                } header: {
                    MonthSectionHeader(title: MonthSectionFormatting.monthTitle(year: section.year, month: section.month))
                } footer: {
                    Text(MonthSectionFormatting.footerText(for: section))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("行程记录")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: Trip.self) { trip in
            TripDetailView(trip: trip)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        exportAllSummary()
                    } label: {
                        Label("导出全部摘要 CSV", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(trips.isEmpty)
            }
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

private struct MonthSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title2.weight(.bold))
            .textCase(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }
}

private struct TripRowView: View {
    let trip: Trip

    private var endpoints: (startLat: Double?, startLon: Double?, endLat: Double?, endLon: Double?) {
        trip.resolvedEndpointLatLon()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(trip.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                if trip.endedAt == nil {
                    Text("进行中")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
            }
            Text(String(format: "%.2f 公里", trip.totalDistanceMeters / 1000))
                .font(.headline)
            if let ended = trip.endedAt {
                Text("结束 \(ended.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            let ep = endpoints
            AsyncAddressCaption(prefix: "起点", latitude: ep.startLat, longitude: ep.startLon)
            AsyncAddressCaption(prefix: "终点", latitude: ep.endLat, longitude: ep.endLon)
        }
        .padding(.vertical, 2)
    }
}
