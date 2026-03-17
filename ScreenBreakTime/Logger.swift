//

import OSLog

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!
    
    static let notification = Logger(subsystem: subsystem, category: "Notification")
    static let database = Logger(subsystem: subsystem, category: "Database")
    static let session = Logger(subsystem: subsystem, category: "Session")
    static let action = Logger(subsystem: subsystem, category: "Action")
}
