import Foundation

/// Find the maximum screen time allowed at this moment, in whole seconds.
///
/// The maximum screen time is defined such that, at any moment `t`,
/// the on-screen duration cannot exceed `maxScreenTime` in the moving
/// window interval `[t-lookBackDuration, t)`.
///
/// - Parameters:
///   - events: The screen time events, ordered from newer ones to older ones.
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

    var searchInterval = TimeInterval(0)..<maxScreenTime
    while searchInterval.upperBound - searchInterval.lowerBound >= 1.0 {
        let pivotTime = (searchInterval.lowerBound + searchInterval.upperBound) / 2

        let activeUntil = currentTime.addingTimeInterval(pivotTime)
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

    return ((searchInterval.lowerBound + searchInterval.upperBound) / 2).rounded()
}

/// Find the minimum off-screen duration needed before the user can
/// return and stay on-screen for `desiredScreenTime` seconds, in whole
/// seconds.
///
/// - Parameters:
///   - events: The screen time events, ordered from newer ones to older ones.
///   - currentTime: The current time.
///   - lookBackDuration: The moving window size to determine the screen time allowance.
///   - maxScreenTime: The maximum screen time allowed within the look back window.
///   - desiredScreenTime: The desired on-screen duration after returning.
func findRequiredBreakTime(
    events: some Sequence<Event>,
    currentTime: Date,
    lookBackDuration: TimeInterval,
    maxScreenTime: TimeInterval,
    desiredScreenTime: TimeInterval
) -> TimeInterval {
    guard maxScreenTime < lookBackDuration else {
        fatalError("Active time interval must be less than the moving window interval.")
    }
    guard desiredScreenTime <= maxScreenTime else {
        fatalError("Desired screen time must not exceed the maximum screen time.")
    }

    var searchInterval = TimeInterval(0)..<lookBackDuration
    while searchInterval.upperBound - searchInterval.lowerBound >= 1.0 {
        let pivotBreak = (searchInterval.lowerBound + searchInterval.upperBound) / 2

        let resumeTime = currentTime.addingTimeInterval(pivotBreak)
        let activeUntil = resumeTime.addingTimeInterval(desiredScreenTime)

        let simulatedEvents =
            [Event(timestamp: resumeTime, state: .active),
             Event(timestamp: currentTime, state: .inactive)]
            + Array(events)

        if canBeOnScreen(
            until: activeUntil,
            events: simulatedEvents,
            currentTime: resumeTime,
            lookBackDuration: lookBackDuration,
            maxScreenTime: maxScreenTime)
        {
            searchInterval = searchInterval.lowerBound..<pivotBreak
        } else {
            searchInterval = pivotBreak..<searchInterval.upperBound
        }
    }

    return ((searchInterval.lowerBound + searchInterval.upperBound) / 2).rounded()
}

private func canBeOnScreen(
    until futureTime: Date,
    events: some Sequence<Event>,
    currentTime: Date,
    lookBackDuration: TimeInterval,
    maxScreenTime: TimeInterval
) -> Bool {
    let movingWindowStartTime = futureTime.addingTimeInterval(-lookBackDuration)

    // `totalActiveTime` will have the total active screen time from
    // `currentTime - lookBackduration` to `futureTime`. The initial
    // value is set assuming the user will stay on-screen from now to
    // `futureTime`.
    var totalActiveTime = currentTime.distance(to: futureTime)

    // Now, look back `events` sequence and include on-screen time
    // intervals which the user has spent already to
    // `totalActiveTime`.
    var sessionEndTime = currentTime
    var active = false
    var heartBeatTime = currentTime
    for event in events {
        if event.timestamp.distance(to: heartBeatTime) > lookBackDuration {
            // This `event` (say, `event(t)`) was older than the look
            // back duration, meaning that the system has been off
            // until `event(t+1).timestamp`.
            active = false
            break
        }

        heartBeatTime = event.timestamp

        if event.state == .heartBeat {
            continue
        }

        active = event.state == .active
        if event.timestamp < movingWindowStartTime {
            break
        }

        if active {
            totalActiveTime += event.timestamp.distance(to: sessionEndTime)
        }

        sessionEndTime = event.timestamp
        active = false
    }

    if active {
        totalActiveTime += movingWindowStartTime.distance(to: sessionEndTime)
    }

    return totalActiveTime <= maxScreenTime
}
