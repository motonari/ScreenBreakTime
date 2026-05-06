import AppKit
import Combine
import Foundation
import OSLog
import SwiftData

struct RemainingTime: Equatable {
    var duration: TimeInterval

    // Make every remainingTime calculation unique so that we trigger
    // the system sleep condition check every time even if the
    // remaining time doesn't change.
    //
    // It is important to trigger the system sleep immediately again
    // when the user wakes up the system while it is sleeping and the
    // remaining time is still zero.
    var uuid = UUID()
}

class ScreenTimeMonitor: ObservableObject {
    @Published var remainingTime = RemainingTime(duration: 0.0)
    @Published var records: [Event] = []

    static let shared = ScreenTimeMonitor()

    let modelContainer: ModelContainer

    private init() {
        do {
            let url = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            )
            .first!
            .appending(
                components: "ScreenBreakTime", "ScreenBreakTime.store",
                directoryHint: .notDirectory)

            let modelContainer = try ModelContainer(
                for: Event.self,
                configurations: ModelConfiguration(url: url))

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
        let modelContext = modelContainer.mainContext

        recordScreenTimeStart(modelContext: modelContext)
        registerNotificationObservers(modelContext: modelContext)
        while true {
            recordHeartBeat(modelContext: modelContext)
            updateRemainingTime(modelContext: modelContext)
            deleteOldRecords(modelContext: modelContext)

            try? await Task.sleep(for: .seconds(10))
        }
    }

    private func registerNotificationObservers(modelContext: ModelContext) {
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
    }

    private func recordScreenTimeStart(modelContext: ModelContext) {
        let event = Event(timestamp: .now, state: .active)
        modelContext.insert(event)
    }

    private func updateRemainingTime(modelContext: ModelContext) {
        var fetchDescriptor = FetchDescriptor<Event>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)],
        )
        fetchDescriptor.includePendingChanges = false
        do {
            let records = try modelContext.fetch(fetchDescriptor, batchSize: 10)

            self.records = Array(records)
            let duration = findRemainingScreenTime(
                events: records,
                currentTime: .now,
                lookBackDuration: 60 * 60,
                maxScreenTime: 60 * 45)
            remainingTime = RemainingTime(duration: duration)

        } catch {
            Logger.database.error("Failed to read from the database: \(error.localizedDescription)")
        }
    }

    private func recordHeartBeat(modelContext: ModelContext) {
        let screenTime = Event(timestamp: .now, state: .heartBeat)
        modelContext.insert(screenTime)
    }

    private func deleteOldRecords(modelContext: ModelContext) {
        let oneDayAgo = Date.now.addingTimeInterval(-24 * 60 * 60)
        let predicate = #Predicate<Event> { record in
            record.timestamp < oneDayAgo
        }

        do {
            try modelContext.delete(model: Event.self, where: predicate)
        } catch {
            Logger.database.error("Failed to delete old records: \(error.localizedDescription)")
        }
    }

}
