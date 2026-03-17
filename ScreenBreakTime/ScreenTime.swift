//
import SwiftData
import Foundation

enum State: Int, Codable {
    case inactive
    case active
    case heartBeat
    
}

@Model
class ScreenTime {
    var timestamp: Date
    var state = State.active
    
    init(timestamp: Date, state: State) {
        self.timestamp = timestamp
        self.state = state
    }
}
