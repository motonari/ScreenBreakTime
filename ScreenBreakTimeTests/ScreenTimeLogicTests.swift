//

import Testing
import ScreenBreakTime
import Foundation

struct ScreenTimeLogicTests {
    
    @Test func emptyRecords() async throws {
        let remainingTime = calculateRemainingTime(
            records: [],
            currentTime: .now,
            movingWindowInterval: 10,
            maxActiveTimeInterval: 9)
        
        #expect(remainingTime == 9)
    }
    
    @Test func rightAfterStart() async throws {
        let now = Date.now
        let record = ScreenTime(timestamp: now, state: .active)
        let remainingTime = calculateRemainingTime(
            records: [record],
            currentTime: now,
            movingWindowInterval: 10,
            maxActiveTimeInterval: 9)
        
        #expect(remainingTime == 9)
    }
    
    @Test func usingMoreThanWindowInterval() async throws {
        let now = Date.now
        let record = ScreenTime(timestamp: now.addingTimeInterval(-11), state: .active)
        let remainingTime = calculateRemainingTime(
            records: [record],
            currentTime: now,
            movingWindowInterval: 10,
            maxActiveTimeInterval: 9)
        
        #expect(remainingTime == 0)
    }

    @Test func timeUp() async throws {
        let now = Date.now
        let record = ScreenTime(timestamp: now.addingTimeInterval(-9), state: .active)
        let remainingTime = calculateRemainingTime(
            records: [record],
            currentTime: now,
            movingWindowInterval: 10,
            maxActiveTimeInterval: 9)
        
        #expect(remainingTime == 0)
    }

    @Test func tookSomeRestInTheMiddle() async throws {
        // ***----***
        //
        let now = Date.now
        let records = [
            ScreenTime(timestamp: now.addingTimeInterval(-3), state: .active),
            ScreenTime(timestamp: now.addingTimeInterval(-7), state: .inactive),
            ScreenTime(timestamp: now.addingTimeInterval(-10), state: .active),
        ]
        let remainingTime = calculateRemainingTime(
            records: records,
            currentTime: now,
            movingWindowInterval: 10,
            maxActiveTimeInterval: 9)
        
        #expect(remainingTime == 6)
    }

    @Test func tookShortRestInTheMiddle() async throws {
        // Current: *-********
        // 1 more : -*********, OK
        // 2 more : **********, NG
        let now = Date.now
        let records = [
            ScreenTime(timestamp: now.addingTimeInterval(-8), state: .active),
            ScreenTime(timestamp: now.addingTimeInterval(-9), state: .inactive),
            ScreenTime(timestamp: now.addingTimeInterval(-10), state: .active),
        ]
        let remainingTime = calculateRemainingTime(
            records: records,
            currentTime: now,
            movingWindowInterval: 10,
            maxActiveTimeInterval: 9)
        
        #expect(remainingTime == 1)
    }

    @Test func afterResting() async throws {
        let now = Date.now
        let records = [
            ScreenTime(timestamp: now.addingTimeInterval(-5), state: .inactive),
            ScreenTime(timestamp: now.addingTimeInterval(-10), state: .active),
        ]
        let remainingTime = calculateRemainingTime(
            records: records,
            currentTime: now,
            movingWindowInterval: 10,
            maxActiveTimeInterval: 5)
        
        #expect(remainingTime == 5)
    }

    @Test func forciblyTerminatedCorruptedRecord() async throws {
        let now = Date.now
        let records = [
            ScreenTime(timestamp: now.addingTimeInterval(-70), state: .active),
        ]
        let remainingTime = calculateRemainingTime(
            records: records,
            currentTime: now,
            movingWindowInterval: 10,
            maxActiveTimeInterval: 9)
        
        #expect(remainingTime == 9)
    }

    @Test func hasBeenActiveSinceLongTimeAgo() async throws {
        let now = Date.now
        let records = [
            ScreenTime(timestamp: now.addingTimeInterval(-10), state: .heartBeat),
            ScreenTime(timestamp: now.addingTimeInterval(-20), state: .heartBeat),
            ScreenTime(timestamp: now.addingTimeInterval(-30), state: .heartBeat),
            ScreenTime(timestamp: now.addingTimeInterval(-40), state: .heartBeat),
            ScreenTime(timestamp: now.addingTimeInterval(-50), state: .heartBeat),
            ScreenTime(timestamp: now.addingTimeInterval(-60), state: .heartBeat),
            ScreenTime(timestamp: now.addingTimeInterval(-70), state: .active),
        ]
        let remainingTime = calculateRemainingTime(
            records: records,
            currentTime: now,
            movingWindowInterval: 10,
            maxActiveTimeInterval: 9)
        
        #expect(remainingTime == 0)
    }
}
