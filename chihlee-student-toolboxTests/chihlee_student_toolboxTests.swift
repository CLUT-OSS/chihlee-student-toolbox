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

}
