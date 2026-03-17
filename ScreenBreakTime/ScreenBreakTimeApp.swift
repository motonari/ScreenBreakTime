//

import SwiftUI
import AppKit
import Foundation
import SwiftData
import OSLog
import ServiceManagement

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
            struct Announcement {
                let remainingTimeInterval: TimeInterval
                let message: String
            }
            
            let announcements = [
                Announcement(remainingTimeInterval: 60 * 10, message: "10 minutes. Prepare to break."),
                Announcement(remainingTimeInterval: 60 * 5, message: "5 minutes. Please take a break now."),
                Announcement(remainingTimeInterval: 60 * 4, message: "4 minutes. Forcible break process was initiated."),
                Announcement(remainingTimeInterval: 60 * 3, message: "3 minutes. You don't have much time."),
                Announcement(remainingTimeInterval: 60 * 2, message: "2 minutes. Oh no, an asteroid is approaching."),
                Announcement(remainingTimeInterval: 60 * 1, message: "1 minute. Alert! Alert! Take a break now!"),
                Announcement(remainingTimeInterval: 30,     message: "30 seconds. This computer goes to sleep."),
            ]
            
            for announcement in announcements {
                if newValue <= announcement.remainingTimeInterval,
                   announcement.remainingTimeInterval < oldValue {
                    Task {
                        await speechManager.speak(announcement.message)
                    }
                }
            }
            
            if newValue <= 0 {
                Logger.action.log("Invoking /usr/bin/pmset sleepnow")

                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
                process.arguments = ["sleepnow"]
                try! process.run()
            }
        }

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
