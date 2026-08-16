import AppKit
import Foundation
import OSLog
import ServiceManagement
import SwiftData
import SwiftUI

@main
struct ScreenBreakTimeApp: App {
    @ObservedObject var monitor = ScreenTimeMonitor.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let speechManager = SpeechManager()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .frame(width: 300, height: 200)
                .environmentObject(monitor)

        } label: {
            Image(systemName: "hourglass")
        }
        .menuBarExtraStyle(.window)
        .onChange(of: monitor.remainingTime) { oldValue, newValue in
            makeAnnouncement(
                previousRemainingTime: oldValue.duration,
                currentRemainingTime: newValue.duration,
                requiredBreakTime: newValue.requiredBreak
            )

            if newValue.duration <= 0 {
                sleepNow()
            }
        }
    }

    private func timeAnnouncement(for duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration.truncatingRemainder(dividingBy: 3600)) / 60
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))

        var message = ""
        if hours != 0 {
            message += "\(hours) hours "
        }

        if minutes != 0 {
            message += "\(minutes) minutes "
        }

        if seconds != 0 || message.isEmpty {
            message += "\(seconds) seconds "
        }

        return message
    }

    private func announcementMessage(
        remainingTime: TimeInterval,
        requiredBreakTime: TimeInterval
    ) -> String {
        return "System goes to sleep in \(timeAnnouncement(for: remainingTime)). "
    }

    private func makeAnnouncement(
        previousRemainingTime: TimeInterval,
        currentRemainingTime: TimeInterval,
        requiredBreakTime: TimeInterval
    ) {
        let triggerTimes: [TimeInterval] = [
            60 * 10,
            60 * 5,
            60 * 4,
            60 * 3,
            60 * 2,
            60 * 1,
            60 * 0.5,
        ]

        for triggerTime in triggerTimes {
            if (currentRemainingTime <= triggerTime)
                && (triggerTime < previousRemainingTime)
            {
                Task {
                    let message = announcementMessage(
                        remainingTime: triggerTime,
                        requiredBreakTime: requiredBreakTime)
                    await speechManager.speak(message)
                }
            }
        }
    }

    private func sleepNow() {
        Logger.action.log("Invoking /usr/bin/pmset sleepnow")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["sleepnow"]
        try! process.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            // Register the main application as a login item
            try SMAppService.mainApp.register()
        } catch {
            fatalError("Failed to register login item: \(error.localizedDescription)")
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Logger.notification.log("Terminating the application.")

        let monitor = ScreenTimeMonitor.shared
        monitor.shutdown()
        return .terminateNow
    }
}
