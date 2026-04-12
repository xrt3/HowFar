//
//  ContentView.swift
//  MileMate
//
//  Created by BigTong on 2026/4/12.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @StateObject private var locationService = LocationTrackingService()

    var body: some View {
        NavigationStack {
            MapScreenView()
                .toolbar(.hidden, for: .navigationBar)
        }
        .environmentObject(locationService)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Trip.self, TripPoint.self], inMemory: true)
}
