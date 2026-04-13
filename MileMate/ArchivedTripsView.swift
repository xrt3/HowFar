//
//  ArchivedTripsView.swift
//  MileMate
//

import SwiftData
import SwiftUI

struct ArchivedTripsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Trip> { $0.isArchived == true },
        sort: \Trip.startedAt,
        order: .reverse
    )
    private var trips: [Trip]

    var body: some View {
        Group {
            if trips.isEmpty {
                ContentUnavailableView("暂无已归档行程", systemImage: "archivebox")
            } else {
                List {
                    ForEach(trips) { trip in
                        NavigationLink(value: trip) {
                            TripListRowView(trip: trip)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("删除", role: .destructive) {
                                modelContext.delete(trip)
                            }
                            Button("恢复") {
                                trip.isArchived = nil
                                try? modelContext.save()
                            }
                            .tint(.indigo)
                        }
                    }
                }
            }
        }
        .navigationTitle("已归档")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Trip.self) { trip in
            TripDetailView(trip: trip)
        }
    }
}
