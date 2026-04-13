//
//  TripsListView.swift
//  MileMate
//

import SwiftData
import SwiftUI

struct TripsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Trip> { $0.isArchived != true },
        sort: \Trip.startedAt,
        order: .reverse
    )
    private var trips: [Trip]

    @State private var filterMonthKey: String = ""
    @State private var isSelecting = false
    @State private var selectedTripIDs: Set<UUID> = []
    @State private var shareFile: ShareableTemporaryFile?
    @State private var confirmBulkDelete = false

    private var monthSections: [MonthSection] {
        MonthSection.group(trips)
    }

    private var displayedSections: [MonthSection] {
        if filterMonthKey.isEmpty { return monthSections }
        return monthSections.filter { $0.id == filterMonthKey }
    }

    var body: some View {
        List {
            ForEach(displayedSections) { section in
                Section {
                    ForEach(section.trips) { trip in
                        if isSelecting {
                            Button {
                                toggleSelection(trip.id)
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: selectedTripIDs.contains(trip.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title2)
                                        .foregroundStyle(selectedTripIDs.contains(trip.id) ? Color.accentColor : .secondary)
                                    TripListRowView(trip: trip)
                                }
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink(value: trip) {
                                TripListRowView(trip: trip)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("删除", role: .destructive) {
                                    modelContext.delete(trip)
                                }
                                Button("归档") {
                                    trip.isArchived = true
                                    try? modelContext.save()
                                }
                                .tint(.indigo)
                            }
                        }
                    }
                } header: {
                    MonthSectionHeader(
                        title: MonthSectionFormatting.monthTitle(year: section.year, month: section.month),
                        subtitle: MonthSectionFormatting.monthSubtitle(for: section)
                    )
                }
            }
        }
        .navigationTitle("行程记录")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: Trip.self) { trip in
            TripDetailView(trip: trip)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    ArchivedTripsView()
                } label: {
                    Text("已归档")
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                if isSelecting {
                    Button("完成") {
                        isSelecting = false
                        selectedTripIDs = []
                    }
                    Menu {
                        Button {
                            exportSelectedSummary()
                        } label: {
                            Label("导出所选摘要 CSV", systemImage: "square.and.arrow.up")
                        }
                        .disabled(selectedTripIDs.isEmpty)
                        Button {
                            archiveSelected()
                        } label: {
                            Label("归档所选", systemImage: "archivebox")
                        }
                        .disabled(selectedTripIDs.isEmpty)
                        Button(role: .destructive) {
                            confirmBulkDelete = true
                        } label: {
                            Label("删除所选", systemImage: "trash")
                        }
                        .disabled(selectedTripIDs.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                } else {
                    monthFilterMenu
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
                    Button("选择") {
                        isSelecting = true
                    }
                    .disabled(trips.isEmpty)
                }
            }
        }
        .sheet(item: $shareFile) { item in
            ActivityView(activityItems: [item.url])
        }
        .confirmationDialog(
            "确定删除所选的 \(selectedTripIDs.count) 条行程？此操作无法撤销。",
            isPresented: $confirmBulkDelete,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                deleteSelected()
            }
            Button("取消", role: .cancel) {}
        }
    }

    private var monthFilterMenu: some View {
        Menu {
            Button("全部月份") {
                filterMonthKey = ""
            }
            Divider()
            ForEach(monthSections) { section in
                Button {
                    filterMonthKey = section.id
                } label: {
                    let title = MonthSectionFormatting.monthTitle(year: section.year, month: section.month)
                    if filterMonthKey == section.id {
                        Label(title, systemImage: "checkmark")
                    } else {
                        Text(title)
                    }
                }
            }
        } label: {
            Image(systemName: "calendar")
        }
        .disabled(monthSections.isEmpty)
    }

    private func toggleSelection(_ id: UUID) {
        if selectedTripIDs.contains(id) {
            selectedTripIDs.remove(id)
        } else {
            selectedTripIDs.insert(id)
        }
    }

    private func selectedTrips() -> [Trip] {
        trips.filter { selectedTripIDs.contains($0.id) }
    }

    private func archiveSelected() {
        for trip in selectedTrips() {
            trip.isArchived = true
        }
        try? modelContext.save()
        selectedTripIDs = []
        isSelecting = false
    }

    private func deleteSelected() {
        for trip in selectedTrips() {
            modelContext.delete(trip)
        }
        try? modelContext.save()
        selectedTripIDs = []
        isSelecting = false
    }

    private func exportAllSummary() {
        let data = CSVExport.tripsSummaryCSV(trips: trips)
        let name = "MileMate-行程摘要-\(fileStamp()).csv"
        guard let url = try? CSVExport.writeTemporaryFile(data: data, name: name) else { return }
        shareFile = ShareableTemporaryFile(url: url)
    }

    private func exportSelectedSummary() {
        let selected = selectedTrips()
        guard !selected.isEmpty else { return }
        let data = CSVExport.tripsSummaryCSV(trips: selected)
        let name = "MileMate-所选行程摘要-\(fileStamp()).csv"
        guard let url = try? CSVExport.writeTemporaryFile(data: data, name: name) else { return }
        shareFile = ShareableTemporaryFile(url: url)
    }

    private func fileStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }
}

private struct MonthSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.weight(.bold))
                .textCase(nil)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
}
