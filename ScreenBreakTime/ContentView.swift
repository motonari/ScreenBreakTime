import AppKit
import SwiftData
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var monitor: ScreenTimeMonitor

    var body: some View {
        VStack {
            Text("Remaining: \(iso8601String(for: monitor.remainingTime))")
                .font(.title)
        }
        .padding()

    }

    func iso8601String(for remainingTimeInterval: TimeInterval) -> String {
        let hours = Int(remainingTimeInterval) / 3600
        let minutes = Int(remainingTimeInterval.truncatingRemainder(dividingBy: 3600)) / 60
        let seconds = Int(remainingTimeInterval.truncatingRemainder(dividingBy: 60))

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

#Preview {
    ContentView()
}
