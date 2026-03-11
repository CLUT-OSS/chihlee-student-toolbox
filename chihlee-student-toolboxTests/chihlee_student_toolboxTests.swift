//
//  chihlee_student_toolboxTests.swift
//  chihlee-student-toolboxTests
//
//  Created by CH ouo on 2026/2/25.
//

import Foundation
import Testing
@testable import chihlee_student_toolbox

struct chihlee_student_toolboxTests {
    @Test func weekIntervalStartsOnMondayAndHasSevenDays() {
        let calendar = DateHelper.calendar
        let friday = calendar.date(from: DateComponents(year: 2026, month: 2, day: 27, hour: 12))!
        let interval = DateHelper.weekInterval(for: friday)
        let start = calendar.dateComponents([.year, .month, .day], from: interval.start)

        #expect(start.year == 2026)
        #expect(start.month == 2)
        #expect(start.day == 23)
        #expect(DateHelper.days(in: interval).count == 7)
    }

    @Test func monthIntervalAndDayEnumeration() {
        let calendar = DateHelper.calendar
        let date = calendar.date(from: DateComponents(year: 2026, month: 2, day: 11, hour: 12))!
        let interval = DateHelper.monthInterval(for: date)
        let start = calendar.dateComponents([.year, .month, .day], from: interval.start)

        #expect(start.year == 2026)
        #expect(start.month == 2)
        #expect(start.day == 1)
        #expect(DateHelper.days(in: interval).count == 28)
    }

    @Test func weekAndMonthTitleFormatting() {
        let calendar = DateHelper.calendar
        let date = calendar.date(from: DateComponents(year: 2026, month: 2, day: 27, hour: 12))!
        let dayTitle = DateHelper.daySectionTitle(date)

        #expect(DateHelper.weekTitle(for: date) == "2/23 - 3/1")
        #expect(DateHelper.monthTitle(for: date) == "2026年2月")
        #expect(dayTitle.hasPrefix("2/27（"))
    }

    @Test func groupedSectionsInRangeScopeAreChronologicalAndHideEmptyDays() throws {
        let calendar = DateHelper.calendar
        let monday = calendar.date(from: DateComponents(year: 2026, month: 2, day: 23, hour: 12))!
        let tuesday = calendar.date(byAdding: .day, value: 1, to: monday)!
        let thursday = calendar.date(byAdding: .day, value: 3, to: monday)!

        let viewModel = HomeworkViewModel()
        viewModel.showMonthView = false
        viewModel.listScope = .range
        viewModel.weekAnchorDate = monday
        viewModel.assignments = [
            Assignment(title: "HW-A", dueDate: monday),
            Assignment(title: "HW-B", dueDate: thursday),
        ]
        let eventJSON = """
        {
          "id": "ev-1",
          "type": "calendar",
          "date": "2026-02-24",
          "timeBegin": "10:00:00",
          "timeEnd": "11:00:00",
          "assignmentName": "DLC Event",
          "content": ""
        }
        """
        let event = try JSONDecoder().decode(DlcCalendarEvent.self, from: Data(eventJSON.utf8))
        viewModel.dlcEvents = [event]

        let sections = viewModel.groupedSectionsForCurrentScope()
        let sectionDates = sections.map { calendar.startOfDay(for: $0.date) }

        #expect(sections.count == 3)
        #expect(sectionDates[0] == calendar.startOfDay(for: monday))
        #expect(sectionDates[1] == calendar.startOfDay(for: tuesday))
        #expect(sectionDates[2] == calendar.startOfDay(for: thursday))
    }

    @Test func dayScopeReturnsOnlySelectedDaySection() {
        let calendar = DateHelper.calendar
        let monday = calendar.date(from: DateComponents(year: 2026, month: 2, day: 23, hour: 12))!
        let wednesday = calendar.date(byAdding: .day, value: 2, to: monday)!

        let viewModel = HomeworkViewModel()
        viewModel.assignments = [
            Assignment(title: "Mon HW", dueDate: monday),
            Assignment(title: "Wed HW", dueDate: wednesday),
        ]
        viewModel.selectDate(wednesday)

        let sections = viewModel.groupedSectionsForCurrentScope()

        #expect(sections.count == 1)
        #expect(calendar.isDate(sections[0].date, inSameDayAs: wednesday))
        #expect(sections[0].assignments.count == 1)
        #expect(sections[0].assignments[0].title == "Wed HW")
    }

    @Test func dlcCalendarEventDecodesNewSchema() throws {
        let json = """
        {
          "action": "homework",
          "assignmentName": "HW1",
          "classCode": "CS101",
          "content": "內容",
          "courseName": "程式設計",
          "date": "2026-03-01",
          "id": "evt-1",
          "rawSubject": "原始標題",
          "semester": "114-2",
          "timeBegin": "09:00:00",
          "timeEnd": "10:00:00",
          "type": "assignment"
        }
        """
        let data = Data(json.utf8)
        let event = try JSONDecoder().decode(DlcCalendarEvent.self, from: data)

        #expect(event.id == "evt-1")
        #expect(event.subject == "HW1")
        #expect(event.date != nil)
        #expect(event.deadlineTime == "10:00")
    }

    @Test func dlcCalendarEventDecodesLegacySchema() throws {
        let json = """
        {
          "idx": "old-1",
          "type": "calendar",
          "memo_date": "2026-03-05",
          "time_begin": "13:00:00",
          "time_end": "15:00:00",
          "subject": "舊版標題",
          "content": "舊版內容"
        }
        """
        let data = Data(json.utf8)
        let event = try JSONDecoder().decode(DlcCalendarEvent.self, from: data)

        #expect(event.id == "old-1")
        #expect(event.subject == "舊版標題")
        #expect(event.date != nil)
        #expect(event.deadlineTime == "15:00")
    }

    @Test func dlcQueryRangeUsesAcademicYearWindow() {
        let calendar = Calendar.current
        let feb = calendar.date(from: DateComponents(year: 2026, month: 2, day: 28, hour: 12))!
        let oct = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 12))!

        let febRange = HomeworkViewModel.dlcQueryRange(referenceDate: feb)
        let octRange = HomeworkViewModel.dlcQueryRange(referenceDate: oct)

        #expect(febRange.start == "2025-08-01")
        #expect(febRange.end == "2026-07-31")
        #expect(octRange.start == "2026-08-01")
        #expect(octRange.end == "2027-07-31")
    }

    @Test func lossyCalendarArraySkipsInvalidEvents() throws {
        let json = """
        [
          {
            "id": "ok-1",
            "type": "course",
            "date": "2026-02-23",
            "assignmentName": "作業 1",
            "content": ""
          },
          {
            "id": 123,
            "type": "course",
            "date": ["broken"],
            "assignmentName": "壞資料",
            "content": ""
          },
          {
            "id": "ok-2",
            "type": "course",
            "date": "2026-02-24",
            "assignmentName": "作業 2",
            "content": ""
          }
        ]
        """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(LossyDecodableArray<DlcCalendarEvent>.self, from: data)

        #expect(decoded.elements.count == 2)
        #expect(decoded.elements[0].id == "ok-1")
        #expect(decoded.elements[1].id == "ok-2")
    }

    @Test func ilifeScoreRankResponseDecodesSamplePayload() throws {
        let json = """
        {
          "status": "success",
          "student": {
            "id": "",
            "name": "",
            "department": "資管系",
            "class": "資三C",
            "program": "日四技",
            "enrollment_status": "在學"
          },
          "rankings": [
            {
              "academic_year": "112",
              "semester": 1,
              "class_rank": { "rank": 36, "total": 56, "percentile": 64.29 },
              "department_rank": { "rank": 114, "total": 175, "percentile": 65.14 }
            },
            {
              "academic_year": "112",
              "semester": 2,
              "class_rank": { "rank": 23, "total": 55, "percentile": 41.82 },
              "department_rank": { "rank": 68, "total": 170, "percentile": 40.0 }
            },
            {
              "academic_year": "113",
              "semester": 1,
              "class_rank": { "rank": 35, "total": 56, "percentile": 62.5 },
              "department_rank": { "rank": 100, "total": 170, "percentile": 58.82 }
            },
            {
              "academic_year": "113",
              "semester": 2,
              "class_rank": { "rank": 32, "total": 57, "percentile": 56.14 },
              "department_rank": { "rank": 91, "total": 172, "percentile": 52.91 }
            },
            {
              "academic_year": "114",
              "semester": 1,
              "class_rank": { "rank": 30, "total": 59, "percentile": 50.85 },
              "department_rank": { "rank": 89, "total": 174, "percentile": 51.15 }
            }
          ],
          "notes": [
            "學期/歷年成績名次之計算人數以當學年度學期末在學人數為基準。"
          ]
        }
        """

        let decoded = try JSONDecoder().decode(APIIlifeScoreRankResponse.self, from: Data(json.utf8))

        #expect(decoded.status == "success")
        #expect(decoded.rankings.count == 5)
        #expect(decoded.rankings[4].academicYear == "114")
        #expect(decoded.rankings[4].semester == 1)
        #expect(decoded.rankings[4].classRank.rank == 30)
        #expect(decoded.rankings[4].departmentRank.total == 174)
    }

    @Test func ilifeScoreRankResponseDecodesNestedDataPayload() throws {
        let json = """
        {
          "status": "success",
          "data": {
            "student": { "id": "" },
            "rankings": [
              {
                "academic_year": 114,
                "semester": "1",
                "class_rank": { "rank": "30", "total": "59", "percentile": "50.85" },
                "department_rank": { "rank": 89, "total": 174, "percentile": 51.15 }
              }
            ]
          }
        }
        """

        let decoded = try JSONDecoder().decode(APIIlifeScoreRankResponse.self, from: Data(json.utf8))
        #expect(decoded.rankings.count == 1)
        #expect(decoded.rankings[0].academicYear == "114")
        #expect(decoded.rankings[0].semester == 1)
        #expect(decoded.rankings[0].classRank.rank == 30)
        #expect(decoded.rankings[0].classRank.total == 59)
    }

    @Test func ilifeDigitalPassDecodesSamplePayload() throws {
        let json = """
        {
          "status": "success",
          "data": {
            "department": "資管系",
            "class": "資三C",
            "student_id": "",
            "name": "",
            "enrollment_status": "在學",
            "activity_fee_status": "未繳交學生活動費",
            "registration_status": "114學年度第2學期已完成註冊"
          }
        }
        """

        struct Envelope: Decodable {
            let data: IlifeDigitalPass?
        }

        let decoded = try JSONDecoder().decode(Envelope.self, from: Data(json.utf8))
        let payload = try #require(decoded.data)
        #expect(payload.department == "資管系")
        #expect(payload.studentClass == "資三C")
        #expect(payload.studentID == "")
        #expect(payload.name == "")
        #expect(payload.enrollmentStatus == "在學")
        #expect(payload.activityFeeStatus == "未繳交學生活動費")
        #expect(payload.registrationStatus == "114學年度第2學期已完成註冊")
    }

    @Test func ilifeDigitalPassEnvelopeMissingDataUsesEmptyFallback() throws {
        let json = """
        {
          "status": "success"
        }
        """

        struct Envelope: Decodable {
            let data: IlifeDigitalPass?
        }

        let decoded = try JSONDecoder().decode(Envelope.self, from: Data(json.utf8))
        let payload = decoded.data ?? IlifeDigitalPass()
        #expect(payload.department.isEmpty)
        #expect(payload.studentClass.isEmpty)
        #expect(payload.studentID.isEmpty)
        #expect(payload.name.isEmpty)
        #expect(payload.enrollmentStatus.isEmpty)
        #expect(payload.activityFeeStatus.isEmpty)
        #expect(payload.registrationStatus.isEmpty)
    }

    @Test func rankingMapUsesSemesterCodeKey() {
        let ranking = APIIlifeScoreRanking(
            academicYear: "114",
            semester: 1,
            classRank: APIIlifeRankStat(rank: 30, total: 59, percentile: 50.85),
            departmentRank: APIIlifeRankStat(rank: 89, total: 174, percentile: 51.15)
        )

        let key = TranscriptRankingMath.semesterKey(academicYear: ranking.academicYear, semester: ranking.semester)
        let map = TranscriptRankingMath.buildRankingMap(from: [ranking])

        #expect(key == "114-1")
        #expect(map["114-1"]?.classRank == 30)
        #expect(map["114-1"]?.departmentTotal == 174)
    }

    @Test func topPctMatchesReferenceExamples() {
        func rounded1(_ value: Double?) -> Double? {
            guard let value else { return nil }
            return (value * 10).rounded() / 10
        }

        #expect(rounded1(TranscriptRankingMath.topPct(rank: 30, total: 59)) == 49.2)
        #expect(rounded1(TranscriptRankingMath.topPct(rank: 23, total: 55)) == 58.2)
        #expect(rounded1(TranscriptRankingMath.topPct(rank: 68, total: 170)) == 60.0)
        #expect(rounded1(TranscriptRankingMath.topPct(rank: 89, total: 174)) == 48.9)
    }

    @Test func topPctColorThresholdsFollowSpec() {
        #expect(TranscriptRankingMath.topPctColorHex(80) == "#4ade80")
        #expect(TranscriptRankingMath.topPctColorHex(50) == "#60a5fa")
        #expect(TranscriptRankingMath.topPctColorHex(25) == "#facc15")
        #expect(TranscriptRankingMath.topPctColorHex(10) == "#fb923c")
    }

    @Test func rankingMapIsEmptyWhenNoRankingRows() {
        let map = TranscriptRankingMath.buildRankingMap(from: [])
        #expect(map.isEmpty)
    }

    @Test func rankingMapSupportsSemesterAliases() {
        let ranking = APIIlifeScoreRanking(
            academicYear: "114",
            semester: 1,
            classRank: APIIlifeRankStat(rank: 30, total: 59, percentile: 50.85),
            departmentRank: APIIlifeRankStat(rank: 89, total: 174, percentile: 51.15)
        )

        let map = TranscriptRankingMath.buildRankingMap(from: [ranking])
        #expect(map["114-1"] != nil)
        #expect(map["1141"] != nil)
        #expect(map["114 學年度-上學期"] != nil)
    }

    @Test func normalizeSemesterCodeHandlesCommonFormats() {
        #expect(TranscriptRankingMath.normalizeSemesterCode("114-1") == "114-1")
        #expect(TranscriptRankingMath.normalizeSemesterCode("1141") == "114-1")
        #expect(TranscriptRankingMath.normalizeSemesterCode("114 學年度-上學期") == "114-1")
    }

    @Test func dlcCalendarEventOccursOnCoversSingleRangeAndMalformedDate() throws {
        let single = try makeDlcEvent(id: "single", dateString: "2026-03-15")
        let singleDay = try #require(single.date)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: singleDay)!
        #expect(single.occurs(on: singleDay))
        #expect(!single.occurs(on: nextDay))

        let range = try makeDlcEvent(id: "range", dateString: "3/1-3/3")
        let rangeStart = try #require(range.date)
        let rangeMiddle = Calendar.current.date(byAdding: .day, value: 1, to: rangeStart)!
        let rangeAfter = Calendar.current.date(byAdding: .day, value: 3, to: rangeStart)!
        #expect(range.occurs(on: rangeStart))
        #expect(range.occurs(on: rangeMiddle))
        #expect(!range.occurs(on: rangeAfter))

        let malformed = try makeDlcEvent(id: "bad", dateString: "invalid-date")
        #expect(malformed.date == nil)
        #expect(!malformed.occurs(on: Date()))
    }

    @Test @MainActor func monthCacheLoadsCurrentAndAdjacentMonthsOnlyOnce() async {
        actor FetchCallRecorder {
            var starts: [String] = []
            func append(_ start: String) { starts.append(start) }
            func count() -> Int { starts.count }
        }

        let calendar = DateHelper.calendar
        let march = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 12))!
        let recorder = FetchCallRecorder()

        let viewModel = HomeworkViewModel()
        viewModel.showMonthView = true
        viewModel.displayedMonth = march
        viewModel.selectedDate = march
        viewModel.dlcCalendarFetcher = { _, start, _ in
            await recorder.append(start)
            return []
        }

        await viewModel.fetchDlcEvents(token: "token")
        #expect(await recorder.count() == 3)

        await viewModel.fetchDlcEvents(token: "token")
        #expect(await recorder.count() == 3)

        viewModel.changeMonth(by: 1)
        await viewModel.fetchDlcEvents(token: "token")
        #expect(await recorder.count() == 4)

        viewModel.changeMonth(by: -1)
        await viewModel.fetchDlcEvents(token: "token")
        #expect(await recorder.count() == 4)
    }

    @Test @MainActor func monthCacheDedupesEventsAcrossOverlappingMonthResponses() async throws {
        let calendar = DateHelper.calendar
        let march = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 12))!

        let sharedMarch = try makeDlcEvent(id: "shared", dateString: "2026-03-10")
        let sharedApril = try makeDlcEvent(id: "shared", dateString: "2026-04-10")
        let aprilOnly = try makeDlcEvent(id: "apr-only", dateString: "2026-04-11")

        let viewModel = HomeworkViewModel()
        viewModel.showMonthView = true
        viewModel.displayedMonth = march
        viewModel.selectedDate = march
        viewModel.dlcCalendarFetcher = { _, start, _ in
            if start.hasPrefix("2026-03") {
                return [sharedMarch]
            }
            if start.hasPrefix("2026-04") {
                return [sharedApril, aprilOnly]
            }
            return []
        }

        await viewModel.fetchDlcEvents(token: "token")

        let ids = Set(viewModel.dlcEvents.map(\.id))
        #expect(ids == Set(["shared", "apr-only"]))
        #expect(viewModel.dlcEvents.count == 2)
    }

    @Test func dayIndexLookupReturnsAssignmentsAndEventsWithoutFilteringWholeArrays() throws {
        let calendar = DateHelper.calendar
        let day1 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 12))!
        let day2 = calendar.date(byAdding: .day, value: 1, to: day1)!
        let day3 = calendar.date(byAdding: .day, value: 2, to: day1)!

        let viewModel = HomeworkViewModel()
        viewModel.assignments = [
            Assignment(title: "A", dueDate: day1),
            Assignment(title: "B", dueDate: day3),
        ]
        viewModel.dlcEvents = [
            try makeDlcEvent(id: "range", dateString: "3/10-3/11"),
        ]

        #expect(viewModel.assignmentsForDate(day1).count == 1)
        #expect(viewModel.assignmentsForDate(day2).isEmpty)
        #expect(viewModel.eventsForDate(day1).count == 1)
        #expect(viewModel.eventsForDate(day2).count == 1)
        #expect(viewModel.eventsForDate(day3).isEmpty)
    }

    @Test func groupedSectionsLargeDatasetStaysResponsive() {
        let calendar = DateHelper.calendar
        let monthAnchor = calendar.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 12))!

        let viewModel = HomeworkViewModel()
        viewModel.showMonthView = true
        viewModel.displayedMonth = monthAnchor
        viewModel.listScope = .range

        viewModel.assignments = (0..<1200).map { index in
            let dayOffset = index % 28
            let dueDate = calendar.date(byAdding: .day, value: dayOffset, to: monthAnchor)!
            return Assignment(title: "HW-\(index)", dueDate: dueDate)
        }

        viewModel.dlcEvents = (0..<2500).map { index in
            let day = (index % 28) + 1
            let dateText = String(format: "2026-03-%02d", day)
            return DlcCalendarEvent(schoolDateText: dateText, schoolEventTitle: "Event-\(index)")
        }

        let clock = ContinuousClock()
        let start = clock.now
        for _ in 0..<80 {
            _ = viewModel.groupedSectionsForCurrentScope()
        }
        let elapsed = start.duration(to: clock.now)

        #expect(elapsed < .seconds(5))
    }

    private func makeDlcEvent(id: String, dateString: String) throws -> DlcCalendarEvent {
        let json = """
        {
          "id": "\(id)",
          "type": "calendar",
          "date": "\(dateString)",
          "timeBegin": "09:00:00",
          "timeEnd": "10:00:00",
          "assignmentName": "測試事件",
          "content": ""
        }
        """
        return try JSONDecoder().decode(DlcCalendarEvent.self, from: Data(json.utf8))
    }

}
