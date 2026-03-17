//

import SwiftUI
import SwiftData
import AppKit

struct ContentView: View {
    @EnvironmentObject var monitor: ScreenTimeMonitor

    var body: some View {
        VStack {
            Text("Remaining: \(remainingTimeString(for: monitor.remainingTime))")
                .font(.title)
        }
        .padding()

    }
    
    func remainingTimeString(for remainingTimeInterval: TimeInterval) -> String {
        let hours = Int(remainingTimeInterval) / 3600
        let minutes = Int(remainingTimeInterval.truncatingRemainder(dividingBy: 3600)) / 60
        let seconds = Int(remainingTimeInterval.truncatingRemainder(dividingBy: 60))
        
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    func recordDebugString(_ record: ScreenTime) -> String {
        let distance = record.timestamp.distance(to: .now)
        return "\(remainingTimeString(for: distance)) ago: \(record.state)"
    }
}

#Preview {
    ContentView()
}
