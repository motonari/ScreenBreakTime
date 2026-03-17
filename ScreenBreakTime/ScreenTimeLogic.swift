import Foundation

func calculateRemainingTime(
    records: some Sequence<Event>,
    currentTime: Date,
    movingWindowInterval: TimeInterval,
    maxActiveTimeInterval: TimeInterval
) -> TimeInterval {
    guard maxActiveTimeInterval < movingWindowInterval else {
        fatalError("Active time interval must be less than the moving window interval.")
    }

    var searchInterval = 0..<Int(maxActiveTimeInterval) + 1
    while true {
        let pivotTime = (searchInterval.lowerBound + searchInterval.upperBound) / 2
        guard pivotTime != searchInterval.lowerBound,
            pivotTime != searchInterval.upperBound
        else {
            break
        }

        let activeUntil = currentTime.addingTimeInterval(TimeInterval(pivotTime))
        if canActiveUntil(
            currentTime: currentTime,
            activeUntil: activeUntil,
            records: records,
            movingWindowInterval: movingWindowInterval,
            maxActiveTimeInterval: maxActiveTimeInterval)
        {
            searchInterval = pivotTime..<searchInterval.upperBound
        } else {
            searchInterval = searchInterval.lowerBound..<pivotTime
        }
    }

    return TimeInterval(searchInterval.lowerBound)
}

private func canActiveUntil(
    currentTime: Date,
    activeUntil futureTime: Date,
    records: some Sequence<Event>,
    movingWindowInterval: TimeInterval,
    maxActiveTimeInterval: TimeInterval
) -> Bool {
    let movingWindowStartTime = futureTime.addingTimeInterval(-movingWindowInterval)

    var totalActiveTime = currentTime.distance(to: futureTime)

    var sessionEndTime = currentTime
    var active = false
    var heartBeatTime = currentTime
    for screenTime in records {
        if screenTime.timestamp.distance(to: heartBeatTime) > movingWindowInterval {
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
    return maxActiveTimeInterval >= totalActiveTime
}
