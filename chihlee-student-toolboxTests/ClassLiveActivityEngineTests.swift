import Foundation
import Testing
@testable import chihlee_student_toolbox

struct ClassLiveActivityEngineTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func makeDate(hour: Int, minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: 11, hour: hour, minute: minute))!
    }

    @Test func preClassStartsExactlyAtTMinus15() {
        let entry = ClassLiveActivityTimelineEntry(
            sessionID: "ml-1",
            courseName: "機器學習概論",
            classroom: "綜科 404",
            teacher: "陳雅婷",
            classStart: makeDate(hour: 13, minute: 10),
            classEnd: makeDate(hour: 14, minute: 0)
        )

        let now = makeDate(hour: 12, minute: 55)
        let snapshot = ClassLiveActivityEngine.snapshot(now: now, entries: [entry])

        #expect(snapshot != nil)
        #expect(snapshot?.phase == .countdown)
        #expect(snapshot?.phaseStart == makeDate(hour: 12, minute: 55))
        #expect(snapshot?.phaseEnd == makeDate(hour: 13, minute: 10))
    }

    @Test func phaseSwitchesToInClassAtClassStartBoundary() {
        let entry = ClassLiveActivityTimelineEntry(
            sessionID: "ml-1",
            courseName: "機器學習概論",
            classroom: "綜科 404",
            teacher: "陳雅婷",
            classStart: makeDate(hour: 13, minute: 10),
            classEnd: makeDate(hour: 14, minute: 0)
        )

        let now = makeDate(hour: 13, minute: 10)
        let snapshot = ClassLiveActivityEngine.snapshot(now: now, entries: [entry])

        #expect(snapshot != nil)
        #expect(snapshot?.phase == .inClass)
        #expect(snapshot?.phaseStart == makeDate(hour: 13, minute: 10))
        #expect(snapshot?.phaseEnd == makeDate(hour: 14, minute: 0))
    }

    @Test func activityEndsAtClassEndBoundary() {
        let entry = ClassLiveActivityTimelineEntry(
            sessionID: "ml-1",
            courseName: "機器學習概論",
            classroom: "綜科 404",
            teacher: "陳雅婷",
            classStart: makeDate(hour: 13, minute: 10),
            classEnd: makeDate(hour: 14, minute: 0)
        )

        let now = makeDate(hour: 14, minute: 0)
        let snapshot = ClassLiveActivityEngine.snapshot(now: now, entries: [entry])

        #expect(snapshot == nil)
    }

    @Test func selectsCorrectNextClass() {
        let entries = [
            ClassLiveActivityTimelineEntry(
                sessionID: "ml-1",
                courseName: "機器學習概論",
                classroom: "綜科 404",
                teacher: "陳雅婷",
                classStart: makeDate(hour: 13, minute: 10),
                classEnd: makeDate(hour: 14, minute: 0)
            ),
            ClassLiveActivityTimelineEntry(
                sessionID: "db-1",
                courseName: "資料庫系統",
                classroom: "資訊 302",
                teacher: "王小明",
                classStart: makeDate(hour: 14, minute: 10),
                classEnd: makeDate(hour: 15, minute: 0)
            ),
            ClassLiveActivityTimelineEntry(
                sessionID: "algo-1",
                courseName: "演算法",
                classroom: "資訊 306",
                teacher: "林老師",
                classStart: makeDate(hour: 15, minute: 10),
                classEnd: makeDate(hour: 16, minute: 0)
            ),
        ]

        let now = makeDate(hour: 13, minute: 30)
        let snapshot = ClassLiveActivityEngine.snapshot(now: now, entries: entries)

        #expect(snapshot != nil)
        #expect(snapshot?.phase == .inClass)
        #expect(snapshot?.nextCourseName == "資料庫系統")
        #expect(snapshot?.nextClassroom == "資訊 302")
        #expect(snapshot?.nextStart == makeDate(hour: 14, minute: 10))
    }
}
