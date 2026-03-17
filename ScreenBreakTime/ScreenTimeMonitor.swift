//
import CoreGraphics
import Foundation
import SwiftData
import AppKit
import OSLog
import Combine

class ScreenTimeMonitor: ObservableObject {
    @Published var remainingTime: TimeInterval = 0
    @Published var records: [ScreenTime] = []

    static let shared = ScreenTimeMonitor()
    
    let modelContainer: ModelContainer
    private init() {
        do {
            let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first!
                .appending(path: "ScreenBreakTime")
                .appending(path: "ScreenBreakTime.store")
            
            let modelContainer = try ModelContainer(for: ScreenTime.self,
                                                    configurations: ModelConfiguration(url: url))
            let modelContext = modelContainer.mainContext
            
            let workspaceCenter = NSWorkspace.shared.notificationCenter
            workspaceCenter.addObserver(
                forName: NSWorkspace.sessionDidBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { notification in
                Logger.notification.info("Received NSWorkspace.sessionDidBecomeActiveNotification")
                let screenTime = ScreenTime(timestamp: .now, state: .active)
                modelContext.insert(screenTime)
            }
            
            workspaceCenter.addObserver(
                forName: NSWorkspace.sessionDidResignActiveNotification,
                object: nil,
                queue: .main
            ) { notification in
                Logger.notification.info("Received NSWorkspace.sessionDidResignActiveNotification")
                let screenTime = ScreenTime(timestamp: .now, state: .inactive)
                modelContext.insert(screenTime)
            }
            
            DistributedNotificationCenter.default().addObserver(
                forName: .init("com.apple.screenIsLocked"),
                object: nil,
                queue: .main
            ) { notification in
                Logger.notification.info("Received com.apple.screenIsLocked")
                let screenTime = ScreenTime(timestamp: .now, state: .inactive)
                modelContext.insert(screenTime)
            }
            
            DistributedNotificationCenter.default().addObserver(
                forName: .init("com.apple.screenIsUnlocked"),
                object: nil,
                queue: .main
            ) { notification in
                Logger.notification.info("Received com.apple.screenIsUnlocked")
                let screenTime = ScreenTime(timestamp: .now, state: .active)
                modelContext.insert(screenTime)
            }

            let screenTime = ScreenTime(timestamp: .now, state: .active)
            modelContext.insert(screenTime)
            self.modelContainer = modelContainer
            Task {
                await run()
            }
        } catch {
            fatalError("Failed to create monitor: \(error)")
        }
    }
    
    private func updateRemainingTime() {
        var fetchDescriptor = FetchDescriptor<ScreenTime>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)],
        )
        fetchDescriptor.includePendingChanges = false
        do{
            let records = try modelContainer.mainContext.fetch(fetchDescriptor, batchSize: 10)
            
            self.records = Array(records)
            remainingTime = calculateRemainingTime(
                records: records,
                currentTime: .now,
                movingWindowInterval: 60 * 60,
                maxActiveTimeInterval: 60 * 45)
            
        } catch {
            Logger.database.error("Failed to read from the database: \(error.localizedDescription)")
        }
    }

    private func recordHeartBeat() {
        let screenTime = ScreenTime(timestamp: .now, state: .heartBeat)
        modelContainer.mainContext.insert(screenTime)
    }
    
    func run() async {
        while true {
            recordHeartBeat()
            updateRemainingTime()
            deleteOldRecords()
            try? await Task.sleep(for: .seconds(10))
        }
    }
    
    func deleteOldRecords() {
        let oneDayAgo = Date.now.addingTimeInterval(-24 * 60 * 60)
        
        let predicate = #Predicate<ScreenTime> { record in
            record.timestamp < oneDayAgo
        }
        
        do{
            try modelContainer.mainContext.delete(model: ScreenTime.self, where: predicate)
        } catch {
            Logger.database.error("Failed to delete old records: \(error.localizedDescription)")
        }
    }
    
    func shutdown() {
        let screenTime = ScreenTime(timestamp: .now, state: .inactive)
        modelContainer.mainContext.insert(screenTime)
    }
}
