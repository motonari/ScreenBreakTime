import AppKit
import Combine
import Foundation
import OSLog
import SwiftData

class ScreenTimeMonitor: ObservableObject {
    @Published var remainingTime: TimeInterval = 0
    @Published var records: [Event] = []

    static let shared = ScreenTimeMonitor()

    let modelContainer: ModelContainer
    private init() {
        do {
            let url = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            )
            .first!
            .appending(path: "ScreenBreakTime")
            .appending(path: "ScreenBreakTime.store")

            let modelContainer = try ModelContainer(
                for: Event.self,
                configurations: ModelConfiguration(url: url))
            let modelContext = modelContainer.mainContext

            let workspaceCenter = NSWorkspace.shared.notificationCenter
            workspaceCenter.addObserver(
                forName: NSWorkspace.sessionDidBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { notification in
                Logger.notification.info("Received NSWorkspace.sessionDidBecomeActiveNotification")
                let event = Event(timestamp: .now, state: .active)
                modelContext.insert(event)
            }

            workspaceCenter.addObserver(
                forName: NSWorkspace.sessionDidResignActiveNotification,
                object: nil,
                queue: .main
            ) { notification in
                Logger.notification.info("Received NSWorkspace.sessionDidResignActiveNotification")
                let event = Event(timestamp: .now, state: .inactive)
                modelContext.insert(event)
            }

            DistributedNotificationCenter.default().addObserver(
                forName: .init("com.apple.screenIsLocked"),
                object: nil,
                queue: .main
            ) { notification in
                Logger.notification.info("Received com.apple.screenIsLocked")
                let event = Event(timestamp: .now, state: .inactive)
                modelContext.insert(event)
            }

            DistributedNotificationCenter.default().addObserver(
                forName: .init("com.apple.screenIsUnlocked"),
                object: nil,
                queue: .main
            ) { notification in
                Logger.notification.info("Received com.apple.screenIsUnlocked")
                let event = Event(timestamp: .now, state: .active)
                modelContext.insert(event)
            }

            let event = Event(timestamp: .now, state: .active)
            modelContext.insert(event)
            self.modelContainer = modelContainer
            Task {
                await run()
            }
        } catch {
            fatalError("Failed to create monitor: \(error)")
        }
    }

    func shutdown() {
        let event = Event(timestamp: .now, state: .inactive)
        modelContainer.mainContext.insert(event)
    }

    private func run() async {
        while true {
            recordHeartBeat()
            updateRemainingTime()
            deleteOldRecords()
            try? await Task.sleep(for: .seconds(10))
        }
    }

    private func updateRemainingTime() {
        var fetchDescriptor = FetchDescriptor<Event>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)],
        )
        fetchDescriptor.includePendingChanges = false
        do {
            let records = try modelContainer.mainContext.fetch(fetchDescriptor, batchSize: 10)

            self.records = Array(records)
            remainingTime = findRemainingScreenTime(
                events: records,
                currentTime: .now,
                lookBackDuration: 60 * 60,
                maxScreenTime: 60 * 45)

        } catch {
            Logger.database.error("Failed to read from the database: \(error.localizedDescription)")
        }
    }

    private func recordHeartBeat() {
        let screenTime = Event(timestamp: .now, state: .heartBeat)
        modelContainer.mainContext.insert(screenTime)
    }

    private func deleteOldRecords() {
        let oneDayAgo = Date.now.addingTimeInterval(-24 * 60 * 60)

        let predicate = #Predicate<Event> { record in
            record.timestamp < oneDayAgo
        }

        do {
            try modelContainer.mainContext.delete(model: Event.self, where: predicate)
        } catch {
            Logger.database.error("Failed to delete old records: \(error.localizedDescription)")
        }
    }

}
