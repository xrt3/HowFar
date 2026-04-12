//
//  MileMateApp.swift
//  MileMate
//
//  Created by BigTong on 2026/4/12.
//

import Foundation
import SwiftData
import SwiftUI

@main
struct MileMateApp: App {
    private let modelContainer: ModelContainer = {
        let schema = Schema([Trip.self, TripPoint.self])
        let storeURL: URL
        do {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let mileMateDir = appSupport.appending(path: "MileMate", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: mileMateDir, withIntermediateDirectories: true)
            storeURL = mileMateDir.appending(path: "MileMate.store")
        } catch {
            fatalError("无法创建 SwiftData 存储目录: \(error)")
        }
        let config = ModelConfiguration(url: storeURL)
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
