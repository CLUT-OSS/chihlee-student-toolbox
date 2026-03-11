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

    struct MonthKey: Hashable {
        let year: Int
        let month: Int

        var id: String { "\(year)-\(month)" }
        var sortValue: Int { year * 100 + month }
    }

    typealias DlcCalendarFetcher = (_ token: String, _ start: String, _ end: String) async throws -> [DlcCalendarEvent]

    private struct InFlightMonthRequest {
        let id: UUID
        let task: Task<[DlcCalendarEvent], Error>
    }

    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func eventSort(lhs: DlcCalendarEvent, rhs: DlcCalendarEvent) -> Bool {
        let lhsDate = lhs.date ?? .distantFuture
        let rhsDate = rhs.date ?? .distantFuture
        if lhsDate != rhsDate {
            return lhsDate < rhsDate
        }

        let lhsKey = lhs.timeBegin ?? lhs.timeEnd ?? "99:99:99"
        let rhsKey = rhs.timeBegin ?? rhs.timeEnd ?? "99:99:99"
        if lhsKey == rhsKey {
            return lhs.displaySubject < rhs.displaySubject
        }
        return lhsKey < rhsKey
    }

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

    var dlcCalendarFetcher: DlcCalendarFetcher = { token, start, end in
        try await APIService.fetchDlcCalendar(token: token, start: start, end: end)
    }

    private let calendar = DateHelper.calendar

    var selectedDate: Date = DateHelper.calendar.startOfDay(for: Date())
    var weekAnchorDate: Date = DateHelper.calendar.startOfDay(for: Date())
    var displayedMonth: Date = DateHelper.calendar.startOfDay(for: Date())

    var assignments: [Assignment] = [] {
        didSet {
            rebuildAssignmentDayIndex()
        }
    }

    var showMonthView = false
    var listScope: ListScope = .range

    // MARK: - DLC Calendar
    var dlcEvents: [DlcCalendarEvent] = [] {
        didSet {
            rebuildDlcEventDayIndex()
        }
    }

    private var assignmentsByDay: [Date: [Assignment]] = [:]
    private var dlcEventsByDay: [Date: [DlcCalendarEvent]] = [:]

    private var cachedEventsByID: [String: DlcCalendarEvent] = [:]
    private var eventIDsByMonth: [MonthKey: Set<String>] = [:]
    private var monthsByEventID: [String: Set<MonthKey>] = [:]
    private var loadedMonthKeys: Set<MonthKey> = []
    private var inFlightMonthRequests: [MonthKey: InFlightMonthRequest] = [:]
    private var lastToken: String?

    var dlcFetchScopeKey: String {
        let required = sortedMonthKeys(requiredMonthKeysForCurrentScope())
        let scope = showMonthView ? "month" : "week"
        let monthIDs = required.map(\.id).joined(separator: ",")
        return "\(scope)-\(monthIDs)"
    }

    @MainActor
    func fetchDlcEvents(token: String, force: Bool = false) async {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            resetDlcCache()
            return
        }

        if lastToken != trimmedToken {
            resetDlcCache()
            lastToken = trimmedToken
        }

        let required = requiredMonthKeysForCurrentScope()
        let prefetch = prefetchMonthKeys(for: required)
        let demand = required.union(prefetch)
        cancelObsoleteMonthRequests(keeping: demand)

        for monthKey in sortedMonthKeys(required) {
            await loadMonth(monthKey, token: trimmedToken, force: force)
        }

        for monthKey in sortedMonthKeys(prefetch) {
            await loadMonth(monthKey, token: trimmedToken, force: false)
        }
    }

    func dlcEventsForSelectedDate() -> [DlcCalendarEvent] {
        eventsForDate(selectedDate)
    }

    func hasAnyEvent(on date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        return !(assignmentsByDay[day]?.isEmpty ?? true) || !(dlcEventsByDay[day]?.isEmpty ?? true)
    }

    func loadAssignments(context: ModelContext) {
        let descriptor = FetchDescriptor<Assignment>(sortBy: [SortDescriptor(\.dueDate)])
        assignments = (try? context.fetch(descriptor)) ?? []
    }

    func assignmentsForSelectedDate() -> [Assignment] {
        assignmentsForDate(selectedDate)
    }

    func assignmentsForDate(_ date: Date) -> [Assignment] {
        assignmentsByDay[calendar.startOfDay(for: date)] ?? []
    }

    func eventsForDate(_ date: Date) -> [DlcCalendarEvent] {
        dlcEventsByDay[calendar.startOfDay(for: date)] ?? []
    }

    func hasAssignment(on date: Date) -> Bool {
        !(assignmentsByDay[calendar.startOfDay(for: date)]?.isEmpty ?? true)
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
        let day = calendar.startOfDay(for: date)
        selectedDate = day
        weekAnchorDate = day
        displayedMonth = day
        listScope = .day
    }

    func resetToRangeScope() {
        listScope = .range
    }

    func changeWeek(by value: Int) {
        guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: value, to: weekAnchorDate) else {
            return
        }
        weekAnchorDate = nextWeek

        if isDayScope {
            let currentWeekStart = DateHelper.startOfWeekMonday(for: selectedDate)
            let dayOffset = calendar.dateComponents([.day], from: currentWeekStart, to: selectedDate).day ?? 0
            let newWeekStart = DateHelper.startOfWeekMonday(for: nextWeek)
            selectedDate = calendar.date(byAdding: .day, value: dayOffset, to: newWeekStart) ?? newWeekStart
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
        guard let nextMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else {
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

    private func rebuildAssignmentDayIndex() {
        let grouped = Dictionary(grouping: assignments) { assignment in
            calendar.startOfDay(for: assignment.dueDate)
        }
        assignmentsByDay = grouped.mapValues { groupedAssignments in
            groupedAssignments.sorted { $0.dueDate < $1.dueDate }
        }
    }

    private func rebuildDlcEventDayIndex() {
        var grouped: [Date: [DlcCalendarEvent]] = [:]
        for event in dlcEvents {
            guard let range = event.dayRange else { continue }
            var currentDay = range.lowerBound
            while currentDay <= range.upperBound {
                grouped[currentDay, default: []].append(event)
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else { break }
                currentDay = nextDay
            }
        }
        for key in grouped.keys {
            grouped[key]?.sort(by: Self.eventSort(lhs:rhs:))
        }
        dlcEventsByDay = grouped
    }

    @MainActor
    private func loadMonth(_ monthKey: MonthKey, token: String, force: Bool) async {
        if force {
            invalidateCachedMonth(monthKey)
        } else if loadedMonthKeys.contains(monthKey) {
            return
        }

        if let inFlight = inFlightMonthRequests[monthKey] {
            _ = try? await inFlight.task.value
            return
        }

        let range = monthQueryRange(for: monthKey)
        let requestID = UUID()
        let task = Task {
            try await dlcCalendarFetcher(token, range.start, range.end)
        }
        inFlightMonthRequests[monthKey] = InFlightMonthRequest(id: requestID, task: task)

        do {
            let fetchedEvents = try await task.value
            if Task.isCancelled { return }
            applyFetchedEvents(fetchedEvents, to: monthKey)
        } catch is CancellationError {
            // Ignore cancelled fetches; a newer request is already in-flight.
        } catch {
            // Keep current cached data on fetch errors.
        }

        if inFlightMonthRequests[monthKey]?.id == requestID {
            inFlightMonthRequests.removeValue(forKey: monthKey)
        }
    }

    private func requiredMonthKeysForCurrentScope() -> Set<MonthKey> {
        if showMonthView {
            return [monthKey(for: displayedMonth)]
        }

        let week = DateHelper.weekInterval(for: weekAnchorDate)
        let weekEnd = calendar.date(byAdding: .day, value: -1, to: week.end) ?? week.start
        return [monthKey(for: week.start), monthKey(for: weekEnd)]
    }

    private func prefetchMonthKeys(for required: Set<MonthKey>) -> Set<MonthKey> {
        guard showMonthView, let current = required.first else { return [] }
        return Set(adjacentMonthKeys(for: current))
    }

    private func monthKey(for date: Date) -> MonthKey {
        let components = calendar.dateComponents([.year, .month], from: date)
        return MonthKey(year: components.year ?? 1970, month: components.month ?? 1)
    }

    private func monthStartDate(for monthKey: MonthKey) -> Date {
        calendar.date(from: DateComponents(year: monthKey.year, month: monthKey.month, day: 1))
            ?? calendar.startOfDay(for: Date())
    }

    private func adjacentMonthKeys(for monthKey: MonthKey) -> [MonthKey] {
        let monthStart = monthStartDate(for: monthKey)
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: monthStart).map(monthKey(for:))
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart).map(monthKey(for:))
        return [previousMonth, nextMonth].compactMap { $0 }
    }

    private func monthQueryRange(for monthKey: MonthKey) -> (start: String, end: String) {
        let startDate = monthStartDate(for: monthKey)
        let monthInterval = DateHelper.monthInterval(for: startDate)
        let endDate = calendar.date(byAdding: .day, value: -1, to: monthInterval.end) ?? monthInterval.start

        return (
            Self.apiDateFormatter.string(from: monthInterval.start),
            Self.apiDateFormatter.string(from: endDate)
        )
    }

    private func sortedMonthKeys(_ monthKeys: Set<MonthKey>) -> [MonthKey] {
        monthKeys.sorted { lhs, rhs in lhs.sortValue < rhs.sortValue }
    }

    private func cancelObsoleteMonthRequests(keeping demanded: Set<MonthKey>) {
        let staleKeys = inFlightMonthRequests.keys.filter { !demanded.contains($0) }
        for key in staleKeys {
            inFlightMonthRequests[key]?.task.cancel()
            inFlightMonthRequests.removeValue(forKey: key)
        }
    }

    private func invalidateCachedMonth(_ monthKey: MonthKey) {
        loadedMonthKeys.remove(monthKey)
        inFlightMonthRequests[monthKey]?.task.cancel()
        inFlightMonthRequests.removeValue(forKey: monthKey)

        guard let existingIDs = eventIDsByMonth.removeValue(forKey: monthKey) else { return }
        for id in existingIDs {
            guard var monthSet = monthsByEventID[id] else { continue }
            monthSet.remove(monthKey)
            if monthSet.isEmpty {
                monthsByEventID.removeValue(forKey: id)
                cachedEventsByID.removeValue(forKey: id)
            } else {
                monthsByEventID[id] = monthSet
            }
        }
        updateAggregatedEvents()
    }

    private func applyFetchedEvents(_ events: [DlcCalendarEvent], to monthKey: MonthKey) {
        let oldIDs = eventIDsByMonth[monthKey] ?? []
        var newIDs: Set<String> = []

        for event in events {
            newIDs.insert(event.id)
            cachedEventsByID[event.id] = event
            monthsByEventID[event.id, default: []].insert(monthKey)
        }

        let removedIDs = oldIDs.subtracting(newIDs)
        for id in removedIDs {
            guard var monthSet = monthsByEventID[id] else { continue }
            monthSet.remove(monthKey)
            if monthSet.isEmpty {
                monthsByEventID.removeValue(forKey: id)
                cachedEventsByID.removeValue(forKey: id)
            } else {
                monthsByEventID[id] = monthSet
            }
        }

        eventIDsByMonth[monthKey] = newIDs
        loadedMonthKeys.insert(monthKey)
        updateAggregatedEvents()
    }

    private func updateAggregatedEvents() {
        dlcEvents = cachedEventsByID.values.sorted(by: Self.eventSort(lhs:rhs:))
    }

    private func resetDlcCache() {
        for request in inFlightMonthRequests.values {
            request.task.cancel()
        }
        inFlightMonthRequests.removeAll()
        loadedMonthKeys.removeAll()
        eventIDsByMonth.removeAll()
        monthsByEventID.removeAll()
        cachedEventsByID.removeAll()
        dlcEvents = []
        lastToken = nil
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
