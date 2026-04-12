//
//  MileMateApp.swift
//  MileMate
//
//  Created by BigTong on 2026/4/12.
//

import SwiftData
import SwiftUI

@main
struct MileMateApp: App {
    private let modelContainer: ModelContainer = {
        let schema = Schema([Trip.self, TripPoint.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("SwiftData container failed: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
