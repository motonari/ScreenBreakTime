import Foundation

/// Find the maximum screen time allowed at this moment.
///
/// The maximum screen time is defined such that, at any moment `t`,
/// the on-screen duration cannot exceed `maxScreenTime` in the moving
/// window interval `[t-lookBackDuration, t)`.
///
/// - Parameters:
///   - events: The screen time events.
///   - currentTime: The current time.
///   - lookBackDuration: The moving window size to determine the screen time allowance.
///   - maxScreenTime: The maximum screen time allowed within the look back window.
func findRemainingScreenTime(
    events: some Sequence<Event>,
    currentTime: Date,
    lookBackDuration: TimeInterval,
    maxScreenTime: TimeInterval
) -> TimeInterval {
    guard maxScreenTime < lookBackDuration else {
        fatalError("Active time interval must be less than the moving window interval.")
    }

    var searchInterval = 0..<Int(maxScreenTime) + 1
    while true {
        let pivotTime = (searchInterval.lowerBound + searchInterval.upperBound) / 2
        guard pivotTime != searchInterval.lowerBound,
            pivotTime != searchInterval.upperBound
        else {
            break
        }

        let activeUntil = currentTime.addingTimeInterval(TimeInterval(pivotTime))
        if canBeOnScreen(
            until: activeUntil,
            events: events,
            currentTime: currentTime,
            lookBackDuration: lookBackDuration,
            maxScreenTime: maxScreenTime)
        {
            searchInterval = pivotTime..<searchInterval.upperBound
        } else {
            searchInterval = searchInterval.lowerBound..<pivotTime
        }
    }

    return TimeInterval(searchInterval.lowerBound)
}

private func canBeOnScreen(
    until futureTime: Date,
    events: some Sequence<Event>,
    currentTime: Date,
    lookBackDuration: TimeInterval,
    maxScreenTime: TimeInterval
) -> Bool {
    let movingWindowStartTime = futureTime.addingTimeInterval(-lookBackDuration)

    var totalActiveTime = currentTime.distance(to: futureTime)

    var sessionEndTime = currentTime
    var active = false
    var heartBeatTime = currentTime
    for screenTime in events {
        if screenTime.timestamp.distance(to: heartBeatTime) > lookBackDuration {
            active = false
            break
        }

        heartBeatTime = screenTime.timestamp

        if screenTime.state == .heartBeat {
            continue
        }

        active = screenTime.state == .active
        if screenTime.timestamp < movingWindowStartTime {
            break
        }

        if active {
            totalActiveTime += screenTime.timestamp.distance(to: sessionEndTime)
        }

        sessionEndTime = screenTime.timestamp
        active = false
    }

    if active {
        totalActiveTime += movingWindowStartTime.distance(to: sessionEndTime)
    }
    return maxScreenTime >= totalActiveTime
}
