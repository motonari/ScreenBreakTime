//

import Foundation
import ScreenBreakTime
import Testing

struct ScreenTimeLogicTests {

    @Test func emptyRecords() async throws {
        let remainingTime = findRemainingScreenTime(
            events: [],
            currentTime: .now,
            lookBackDuration: 10,
            maxScreenTime: 9)

        #expect(remainingTime == 9)
    }

    @Test func rightAfterStart() async throws {
        let now = Date.now
        let event = Event(timestamp: now, state: .active)
        let remainingTime = findRemainingScreenTime(
            events: [event],
            currentTime: now,
            lookBackDuration: 10,
            maxScreenTime: 9)

        #expect(remainingTime == 9)
    }

    @Test func usingMoreThanWindowInterval() async throws {
        let now = Date.now
        let event = Event(timestamp: now.addingTimeInterval(-11), state: .active)
        let remainingTime = findRemainingScreenTime(
            events: [event],
            currentTime: now,
            lookBackDuration: 10,
            maxScreenTime: 9)

        #expect(remainingTime == 9)
    }

    @Test func timeUp() async throws {
        let now = Date.now
        let event = Event(timestamp: now.addingTimeInterval(-9), state: .active)
        let remainingTime = findRemainingScreenTime(
            events: [event],
            currentTime: now,
            lookBackDuration: 10,
            maxScreenTime: 9)

        #expect(remainingTime == 0)
    }

    @Test func tookSomeRestInTheMiddle() async throws {
        // ***----***
        //
        let now = Date.now
        let events = [
            Event(timestamp: now.addingTimeInterval(-3), state: .active),
            Event(timestamp: now.addingTimeInterval(-7), state: .inactive),
            Event(timestamp: now.addingTimeInterval(-10), state: .active),
        ]
        let remainingTime = findRemainingScreenTime(
            events: events,
            currentTime: now,
            lookBackDuration: 10,
            maxScreenTime: 9)

        #expect(remainingTime == 6)
    }

    @Test func tookShortRestInTheMiddle() async throws {
        // Current: *-********
        // 1 more : -*********, OK
        // 2 more : **********, NG
        let now = Date.now
        let events = [
            Event(timestamp: now.addingTimeInterval(-8), state: .active),
            Event(timestamp: now.addingTimeInterval(-9), state: .inactive),
            Event(timestamp: now.addingTimeInterval(-10), state: .active),
        ]
        let remainingTime = findRemainingScreenTime(
            events: events,
            currentTime: now,
            lookBackDuration: 10,
            maxScreenTime: 9)

        #expect(remainingTime == 1)
    }

    @Test func afterResting() async throws {
        let now = Date.now
        let events = [
            Event(timestamp: now.addingTimeInterval(-5), state: .inactive),
            Event(timestamp: now.addingTimeInterval(-10), state: .active),
        ]
        let remainingTime = findRemainingScreenTime(
            events: events,
            currentTime: now,
            lookBackDuration: 10,
            maxScreenTime: 5)

        #expect(remainingTime == 5)
    }

    @Test func forciblyTerminatedCorruptedRecord() async throws {
        let now = Date.now
        let events = [
            Event(timestamp: now.addingTimeInterval(-70), state: .active)
        ]
        let remainingTime = findRemainingScreenTime(
            events: events,
            currentTime: now,
            lookBackDuration: 10,
            maxScreenTime: 9)

        #expect(remainingTime == 9)
    }

    @Test func hasBeenActiveSinceLongTimeAgo() async throws {
        let now = Date.now
        let events = [
            Event(timestamp: now.addingTimeInterval(-10), state: .heartBeat),
            Event(timestamp: now.addingTimeInterval(-20), state: .heartBeat),
            Event(timestamp: now.addingTimeInterval(-30), state: .heartBeat),
            Event(timestamp: now.addingTimeInterval(-40), state: .heartBeat),
            Event(timestamp: now.addingTimeInterval(-50), state: .heartBeat),
            Event(timestamp: now.addingTimeInterval(-60), state: .heartBeat),
            Event(timestamp: now.addingTimeInterval(-70), state: .active),
        ]
        let remainingTime = findRemainingScreenTime(
            events: events,
            currentTime: now,
            lookBackDuration: 10,
            maxScreenTime: 9)

        #expect(remainingTime == 0)
    }

    // MARK: - findRequiredBreakTime

    @Test func breakTimeNoHistoryWantsFullSession() async throws {
        // No history, want full 9s session — no break needed.
        let breakTime = findRequiredBreakTime(
            events: [],
            currentTime: .now,
            lookBackDuration: 10,
            maxScreenTime: 9,
            desiredScreenTime: 9)

        #expect(breakTime == 0)
    }

    @Test func breakTimeAfterFullUsage() async throws {
        // Used 9s out of 9s allowed in a 10s window. Want 9s more.
        // A 1s break suffices: as new seconds accumulate, old seconds
        // slide out at the same rate, keeping total at exactly 9s.
        let now = Date.now
        let events = [
            Event(timestamp: now.addingTimeInterval(-9), state: .active),
        ]
        let breakTime = findRequiredBreakTime(
            events: events,
            currentTime: now,
            lookBackDuration: 10,
            maxScreenTime: 9,
            desiredScreenTime: 9)

        #expect(breakTime == 1)
    }

    @Test func breakTimeAfterPartialUsage() async throws {
        // Used 5s out of 9s in a 10s window. Want 5s more.
        // Total would be 10s in the window — need 1s to slide out.
        let now = Date.now
        let events = [
            Event(timestamp: now.addingTimeInterval(-5), state: .active),
        ]
        let breakTime = findRequiredBreakTime(
            events: events,
            currentTime: now,
            lookBackDuration: 10,
            maxScreenTime: 9,
            desiredScreenTime: 5)

        #expect(breakTime == 1)
    }

    @Test func breakTimeWhenAlreadyEnoughRoom() async throws {
        // Used 3s, want 5s. Total 8s < 9s max. No break needed.
        let now = Date.now
        let events = [
            Event(timestamp: now.addingTimeInterval(-3), state: .active),
        ]
        let breakTime = findRequiredBreakTime(
            events: events,
            currentTime: now,
            lookBackDuration: 10,
            maxScreenTime: 9,
            desiredScreenTime: 5)

        #expect(breakTime == 0)
    }

    @Test func breakTimeWithRestInHistory() async throws {
        // ***----***  (3s on, 4s off, 3s on = 6s active in 10s)
        // Want 4s more. At the endpoint (now+4), the window is
        // [now-6, now+4) — the earliest 3s block has slid out, so
        // only 3s old + 4s new = 7s <= 9s. No break needed.
        let now = Date.now
        let events = [
            Event(timestamp: now.addingTimeInterval(-3), state: .active),
            Event(timestamp: now.addingTimeInterval(-7), state: .inactive),
            Event(timestamp: now.addingTimeInterval(-10), state: .active),
        ]
        let breakTime = findRequiredBreakTime(
            events: events,
            currentTime: now,
            lookBackDuration: 10,
            maxScreenTime: 9,
            desiredScreenTime: 4)

        #expect(breakTime == 0)
    }
}
