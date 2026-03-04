import Foundation
import SwiftData
import Observation

struct HomeworkDaySection: Identifiable {
    let date: Date
    let assignments: [Assignment]
    let events: [DlcCalendarEvent]

    var id: Date { DateHelper.calendar.startOfDay(for: date) }
    var title: String { DateHelper.daySectionTitle(date) }
    var isEmpty: Bool { assignments.isEmpty && events.isEmpty }
}

@Observable
final class HomeworkViewModel {
    enum ListScope {
        case range
        case day
    }

    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func dlcQueryRange(referenceDate: Date = Date()) -> (start: String, end: String) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        let year = calendar.component(.year, from: referenceDate)
        let month = calendar.component(.month, from: referenceDate)
        let academicYearStart = month >= 8 ? year : year - 1
        let startDate = calendar.date(from: DateComponents(year: academicYearStart, month: 8, day: 1)) ?? referenceDate
        let endDate = calendar.date(from: DateComponents(year: academicYearStart + 1, month: 7, day: 31)) ?? referenceDate

        return (
            Self.apiDateFormatter.string(from: startDate),
            Self.apiDateFormatter.string(from: endDate)
        )
    }

    var selectedDate: Date = DateHelper.calendar.startOfDay(for: Date())
    var weekAnchorDate: Date = DateHelper.calendar.startOfDay(for: Date())
    var displayedMonth: Date = DateHelper.calendar.startOfDay(for: Date())
    var assignments: [Assignment] = []
    var showMonthView = false
    var listScope: ListScope = .range

    // MARK: - DLC Calendar
    var dlcEvents: [DlcCalendarEvent] = []

    func fetchDlcEvents(token: String) async {
        let range = Self.dlcQueryRange()
        let start = range.start
        let end = range.end
        dlcEvents = (try? await APIService.fetchDlcCalendar(token: token, start: start, end: end)) ?? []
    }

    func dlcEventsForSelectedDate() -> [DlcCalendarEvent] {
        eventsForDate(selectedDate)
    }

    func hasAnyEvent(on date: Date) -> Bool {
        hasAssignment(on: date) ||
        dlcEvents.contains { $0.occurs(on: date) }
    }

    func loadAssignments(context: ModelContext) {
        let descriptor = FetchDescriptor<Assignment>(sortBy: [SortDescriptor(\.dueDate)])
        assignments = (try? context.fetch(descriptor)) ?? []
    }

    func assignmentsForSelectedDate() -> [Assignment] {
        assignments.filter { DateHelper.isSameDay($0.dueDate, selectedDate) }
    }

    func assignmentsForDate(_ date: Date) -> [Assignment] {
        assignments
            .filter { DateHelper.isSameDay($0.dueDate, date) }
            .sorted { $0.dueDate < $1.dueDate }
    }

    func eventsForDate(_ date: Date) -> [DlcCalendarEvent] {
        dlcEvents
            .filter { $0.occurs(on: date) }
            .sorted { lhs, rhs in
                let lhsKey = lhs.timeBegin ?? lhs.timeEnd ?? "99:99:99"
                let rhsKey = rhs.timeBegin ?? rhs.timeEnd ?? "99:99:99"
                if lhsKey == rhsKey {
                    return lhs.displaySubject < rhs.displaySubject
                }
                return lhsKey < rhsKey
            }
    }

    func hasAssignment(on date: Date) -> Bool {
        assignments.contains { DateHelper.isSameDay($0.dueDate, date) }
    }

    func deleteAssignment(_ assignment: Assignment, context: ModelContext) {
        NotificationManager.shared.cancelNotification(identifier: assignment.persistentModelID.hashValue.description)
        context.delete(assignment)
        loadAssignments(context: context)
    }

    func urgencyColor(for assignment: Assignment) -> UrgencyLevel {
        let days = DateHelper.daysUntil(assignment.dueDate)
        if assignment.status == .submitted { return .none }
        if days < 0 { return .overdue }
        if days <= 1 { return .urgent }
        if days <= 3 { return .warning }
        return .none
    }

    var isDayScope: Bool {
        listScope == .day
    }

    var activeRange: DateInterval {
        showMonthView
            ? DateHelper.monthInterval(for: displayedMonth)
            : DateHelper.weekInterval(for: weekAnchorDate)
    }

    var currentRangeTitle: String {
        showMonthView
            ? DateHelper.monthTitle(for: displayedMonth)
            : DateHelper.weekTitle(for: weekAnchorDate)
    }

    var selectedDayFilterTitle: String {
        DateHelper.daySectionTitle(selectedDate)
    }

    var emptyStateDescription: String {
        if isDayScope {
            return "\(selectedDayFilterTitle) 沒有作業或行事曆事件"
        }
        return showMonthView
            ? "本月沒有作業或行事曆事件"
            : "本週沒有作業或行事曆事件"
    }

    func setViewMode(isMonth: Bool) {
        showMonthView = isMonth
        weekAnchorDate = selectedDate
        displayedMonth = selectedDate
        resetToRangeScope()
    }

    func selectDate(_ date: Date) {
        let day = DateHelper.calendar.startOfDay(for: date)
        selectedDate = day
        weekAnchorDate = day
        displayedMonth = day
        listScope = .day
    }

    func resetToRangeScope() {
        listScope = .range
    }

    func changeWeek(by value: Int) {
        guard let nextWeek = DateHelper.calendar.date(byAdding: .weekOfYear, value: value, to: weekAnchorDate) else {
            return
        }
        weekAnchorDate = nextWeek

        if isDayScope {
            let currentWeekStart = DateHelper.startOfWeekMonday(for: selectedDate)
            let dayOffset = DateHelper.calendar.dateComponents([.day], from: currentWeekStart, to: selectedDate).day ?? 0
            let newWeekStart = DateHelper.startOfWeekMonday(for: nextWeek)
            selectedDate = DateHelper.calendar.date(byAdding: .day, value: dayOffset, to: newWeekStart) ?? newWeekStart
            displayedMonth = selectedDate
            return
        }

        let week = DateHelper.weekInterval(for: weekAnchorDate)
        if !week.contains(selectedDate) {
            selectedDate = week.start
        }
        displayedMonth = selectedDate
    }

    func changeMonth(by value: Int) {
        guard let nextMonth = DateHelper.calendar.date(byAdding: .month, value: value, to: displayedMonth) else {
            return
        }
        displayedMonth = nextMonth

        if isDayScope {
            selectedDate = displayedMonth
            weekAnchorDate = displayedMonth
            return
        }

        let month = DateHelper.monthInterval(for: displayedMonth)
        if !month.contains(selectedDate) {
            selectedDate = month.start
        }
        weekAnchorDate = selectedDate
    }

    func groupedSectionsForCurrentScope() -> [HomeworkDaySection] {
        switch listScope {
        case .day:
            return [section(for: selectedDate)]
        case .range:
            return DateHelper.days(in: activeRange)
                .map(section(for:))
                .filter { !$0.isEmpty }
        }
    }

    private func section(for date: Date) -> HomeworkDaySection {
        HomeworkDaySection(
            date: date,
            assignments: assignmentsForDate(date),
            events: eventsForDate(date)
        )
    }

    enum UrgencyLevel {
        case overdue, urgent, warning, none

        var colorName: String {
            switch self {
            case .overdue: "red"
            case .urgent: "orange"
            case .warning: "yellow"
            case .none: "primary"
            }
        }
    }
}
