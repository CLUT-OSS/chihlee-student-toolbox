import Foundation
import SwiftData
import Observation

struct PeriodDefinition: Identifiable {
    let code: String
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int

    var id: String { code }

    var timeRange: String {
        String(format: "%02d:%02d-%02d:%02d", startHour, startMinute, endHour, endMinute)
    }

    var startString: String {
        String(format: "%02d:%02d", startHour, startMinute)
    }

    var endString: String {
        String(format: "%02d:%02d", endHour, endMinute)
    }

    /// Check if the current time falls within this period
    func isCurrent(on date: Date = Date()) -> Bool {
        let cal = Calendar.current
        let now = cal.dateComponents([.hour, .minute], from: date)
        guard let h = now.hour, let m = now.minute else { return false }
        let nowMinutes = h * 60 + m
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute
        return nowMinutes >= startMinutes && nowMinutes < endMinutes
    }
}

struct NonTimedScheduleItem: Identifiable {
    let id: String
    let day: DayOfWeek?
    let periodLabel: String
    let name: String
    let classroom: String
    let teacher: String
    let syllabusURL: String
}

@MainActor
@Observable
final class ScheduleViewModel {
    var sessions: [ClassSession] = []
    var showWeekView = true
    var nonTimedItems: [NonTimedScheduleItem] = []

    /// 平日 (Mon-Fri) period definitions
    static let weekdayPeriods: [PeriodDefinition] = [
        PeriodDefinition(code: "A01", startHour: 8, startMinute: 20, endHour: 9, endMinute: 10),
        PeriodDefinition(code: "A02", startHour: 9, startMinute: 20, endHour: 10, endMinute: 10),
        PeriodDefinition(code: "A03", startHour: 10, startMinute: 20, endHour: 11, endMinute: 10),
        PeriodDefinition(code: "A04", startHour: 11, startMinute: 20, endHour: 12, endMinute: 10),
        PeriodDefinition(code: "A05", startHour: 12, startMinute: 20, endHour: 13, endMinute: 10),
        PeriodDefinition(code: "A06", startHour: 13, startMinute: 20, endHour: 14, endMinute: 10),
        PeriodDefinition(code: "A07", startHour: 14, startMinute: 20, endHour: 15, endMinute: 10),
        PeriodDefinition(code: "A08", startHour: 15, startMinute: 20, endHour: 16, endMinute: 10),
        PeriodDefinition(code: "A09", startHour: 16, startMinute: 20, endHour: 17, endMinute: 10),
        PeriodDefinition(code: "X01", startHour: 17, startMinute: 20, endHour: 18, endMinute: 10),
        PeriodDefinition(code: "B01", startHour: 18, startMinute: 20, endHour: 19, endMinute: 5),
        PeriodDefinition(code: "B02", startHour: 19, startMinute: 10, endHour: 19, endMinute: 55),
        PeriodDefinition(code: "B03", startHour: 20, startMinute: 5, endHour: 20, endMinute: 50),
        PeriodDefinition(code: "B04", startHour: 20, startMinute: 55, endHour: 21, endMinute: 40),
    ]

    /// 星期六 period definitions
    static let saturdayPeriods: [PeriodDefinition] = [
        PeriodDefinition(code: "A01", startHour: 8, startMinute: 30, endHour: 9, endMinute: 15),
        PeriodDefinition(code: "A02", startHour: 9, startMinute: 25, endHour: 10, endMinute: 10),
        PeriodDefinition(code: "A03", startHour: 10, startMinute: 20, endHour: 11, endMinute: 5),
        PeriodDefinition(code: "A04", startHour: 11, startMinute: 15, endHour: 12, endMinute: 0),
        PeriodDefinition(code: "C01", startHour: 13, startMinute: 30, endHour: 14, endMinute: 15),
        PeriodDefinition(code: "C02", startHour: 14, startMinute: 25, endHour: 15, endMinute: 10),
        PeriodDefinition(code: "C03", startHour: 15, startMinute: 20, endHour: 16, endMinute: 5),
        PeriodDefinition(code: "C04", startHour: 16, startMinute: 15, endHour: 17, endMinute: 0),
        PeriodDefinition(code: "C05", startHour: 18, startMinute: 0, endHour: 18, endMinute: 45),
        PeriodDefinition(code: "C06", startHour: 18, startMinute: 55, endHour: 19, endMinute: 40),
        PeriodDefinition(code: "C07", startHour: 19, startMinute: 50, endHour: 20, endMinute: 35),
        PeriodDefinition(code: "C08", startHour: 20, startMinute: 45, endHour: 21, endMinute: 30),
    ]

    static func periods(for day: DayOfWeek) -> [PeriodDefinition] {
        day.isSaturday ? saturdayPeriods : weekdayPeriods
    }

    /// All unique period codes across both weekday and Saturday
    static var allPeriodCodes: [String] {
        var codes: [String] = []
        for p in weekdayPeriods {
            if !codes.contains(p.code) { codes.append(p.code) }
        }
        for p in saturdayPeriods {
            if !codes.contains(p.code) { codes.append(p.code) }
        }
        return codes
    }

    /// Grid rows should include weekday periods plus Saturday-only "C" periods.
    static var gridPeriods: [PeriodDefinition] {
        weekdayPeriods + saturdayPeriods.filter { $0.code.hasPrefix("C") }
    }

    // MARK: - API Sync

    var isSyncing = false
    var syncError: String?
    var syncSuccess = false
    var lastSyncSummary: String?

    func syncFromAPI(token: String, context: ModelContext) async {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            syncError = "尚未登入，無法同步課表"
            return
        }

        isSyncing = true
        syncError = nil
        syncSuccess = false
        lastSyncSummary = nil
        nonTimedItems = []

        do {
            let schedules = try await APIService.fetchSchedule(token: trimmedToken)
            guard let schedule = Self.selectPreferredSchedule(from: schedules) else {
                sessions = []
                lastSyncSummary = "API 回傳 0 份課表"
                isSyncing = false
                return
            }

            // Drop live references first so SwiftUI won't touch deleted objects.
            sessions = []

            // Delete all existing ClassSession objects
            let existing = (try? context.fetch(FetchDescriptor<ClassSession>())) ?? []
            existing.forEach { context.delete($0) }
            let existingNonTimed = (try? context.fetch(FetchDescriptor<NonTimedScheduleEntry>())) ?? []
            existingNonTimed.forEach { context.delete($0) }

            // Create new sessions from API data
            var insertedKeys = Set<String>()
            var parsedSlotCount = 0
            for slot in schedule.slots {
                guard let day = DayOfWeek.from(apiString: slot.weekday) else { continue }
                let codes = Self.periodCodes(from: slot.period, day: day)
                guard !codes.isEmpty else {
                    for apiClass in slot.classes {
                        let key = "nt|\(day.rawValue)|\(slot.period)|\(apiClass.name)|\(apiClass.classroom ?? "")|\(apiClass.teacher ?? "")"
                        guard !insertedKeys.contains(key) else { continue }
                        insertedKeys.insert(key)
                        let entry = NonTimedScheduleEntry(
                            dayOfWeekRaw: day.rawValue,
                            periodLabel: slot.period,
                            name: apiClass.name,
                            classroom: apiClass.classroom ?? "",
                            teacher: apiClass.teacher ?? "",
                            syllabusURL: apiClass.syllabusUrl ?? ""
                        )
                        context.insert(entry)
                    }
                    continue
                }
                parsedSlotCount += 1
                for apiClass in slot.classes {
                    let course = findOrCreateCourse(
                        name: apiClass.name,
                        instructor: apiClass.teacher ?? "",
                        context: context
                    )
                    for code in codes {
                        let dedupeKey = "\(day.rawValue)|\(code)|\(apiClass.name)|\(apiClass.classroom ?? "")|\(apiClass.teacher ?? "")"
                        if insertedKeys.contains(dedupeKey) { continue }
                        insertedKeys.insert(dedupeKey)

                        let session = ClassSession(
                            course: course,
                            dayOfWeek: day,
                            periodCode: code,
                            classroom: apiClass.classroom ?? "",
                            syllabusURL: apiClass.syllabusUrl ?? ""
                        )
                        course.sessions.append(session)
                        context.insert(session)
                    }
                }
            }
            for name in schedule.noTimeCourses where !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let key = "nt|none|\(name)"
                guard !insertedKeys.contains(key) else { continue }
                insertedKeys.insert(key)
                let entry = NonTimedScheduleEntry(
                    dayOfWeekRaw: nil,
                    periodLabel: "非固定節次",
                    name: name,
                    classroom: "",
                    teacher: "",
                    syllabusURL: ""
                )
                context.insert(entry)
            }

            do {
                try context.save()
            } catch {
                context.rollback()
                throw error
            }
            loadSessions(context: context)
            syncSuccess = true
            let loadedTotal = sessions.count
            let loadedWithCourse = sessions.filter { $0.course != nil }.count
            let courseCount = ((try? context.fetch(FetchDescriptor<Course>())) ?? []).count
            let byDay = DayOfWeek.allCases.map { day in
                "\(day.shortName):\(sessions.filter { $0.dayOfWeek == day }.count)"
            }.joined(separator: " ")
            lastSyncSummary = "student=\(schedule.studentID) semester=\(schedule.semester) slots=\(schedule.slots.count) parsed=\(parsedSlotCount) inserted=\(insertedKeys.count) loaded=\(loadedTotal) withCourse=\(loadedWithCourse) courses=\(courseCount) nonTimed=\(nonTimedItems.count) [\(byDay)]"
        } catch is CancellationError {
            // SwiftUI may cancel refresh tasks when gesture/task lifecycle ends.
            syncError = nil
            syncSuccess = false
            lastSyncSummary = "同步被取消"
        } catch let urlError as URLError where urlError.code == .cancelled {
            syncError = nil
            syncSuccess = false
            lastSyncSummary = "同步被取消"
        } catch {
            syncError = error.localizedDescription
            lastSyncSummary = "同步失敗：\(error.localizedDescription)"
        }

        isSyncing = false
    }

    private static func selectPreferredSchedule(from schedules: [APIScheduleData]) -> APIScheduleData? {
        schedules
            .enumerated()
            .max { lhs, rhs in
                if lhs.element.slots.count == rhs.element.slots.count {
                    // Keep backend order when slot counts tie.
                    return lhs.offset > rhs.offset
                }
                return lhs.element.slots.count < rhs.element.slots.count
            }?
            .element
    }

    /// Map eportfolio period strings to internal codes.
    /// Supports numeric values, ranges (e.g. "3-4"), comma-separated values, and direct codes.
    private static func periodCodes(from apiPeriod: String, day: DayOfWeek) -> [String] {
        let cleaned = (apiPeriod.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? apiPeriod)
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "第", with: "")
            .replacingOccurrences(of: "節", with: "")
            .replacingOccurrences(of: "堂", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return [] }

        let tokens = cleaned
            .components(separatedBy: CharacterSet(charactersIn: ",，、/"))
            .flatMap { parsePeriodToken($0, day: day) }
        if !tokens.isEmpty {
            return deduplicated(tokens)
        }
        return parsePeriodToken(cleaned, day: day)
    }

    private static func parsePeriodToken(_ token: String, day: DayOfWeek) -> [String] {
        guard !token.isEmpty else { return [] }

        if let direct = canonicalPeriodCode(token, day: day) {
            return [direct]
        }

        if allPeriodCodes.contains(token) {
            return [token]
        }

        if let n = Int(token), let code = mapNumericPeriod(n, day: day) {
            return [code]
        }

        for separator in ["-", "~", "～", "－", "–", "—"] {
            let parts = token.components(separatedBy: separator).filter { !$0.isEmpty }
            guard parts.count == 2 else { continue }

            if let start = Int(parts[0]), let end = Int(parts[1]) {
                let values: [Int]
                if start <= end {
                    values = Array(start ... end)
                } else {
                    values = Array(stride(from: start, through: end, by: -1))
                }
                let mapped = values.compactMap { mapNumericPeriod($0, day: day) }
                if !mapped.isEmpty { return mapped }
            }

            let codes = periods(for: day).map(\.code)
            guard let startCode = canonicalPeriodCode(parts[0], day: day),
                  let endCode = canonicalPeriodCode(parts[1], day: day),
                  let startIndex = codes.firstIndex(of: startCode),
                  let endIndex = codes.firstIndex(of: endCode)
            else { continue }
            if startIndex <= endIndex {
                return Array(codes[startIndex ... endIndex])
            }
            return Array(codes[endIndex ... startIndex].reversed())
        }

        return []
    }

    private static func canonicalPeriodCode(_ token: String, day: DayOfWeek) -> String? {
        let normalized = token
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !normalized.isEmpty else { return nil }

        if allPeriodCodes.contains(normalized) {
            return normalized
        }

        if let n = Int(normalized) {
            return mapNumericPeriod(n, day: day)
        }

        guard let first = normalized.first, ["A", "B", "C", "X"].contains(String(first)) else {
            return nil
        }

        let numberPart = String(normalized.dropFirst())
        guard let n = Int(numberPart), n > 0 else { return nil }

        switch first {
        case "A":
            return String(format: "A%02d", n)
        case "B":
            return String(format: "B%02d", n)
        case "C":
            return String(format: "C%02d", n)
        case "X":
            return n == 1 ? "X01" : nil
        default:
            return nil
        }
    }

    private static func mapNumericPeriod(_ n: Int, day: DayOfWeek) -> String? {
        if day.isSaturday {
            switch n {
            case 1 ... 4: return String(format: "A%02d", n)
            case 5 ... 12: return String(format: "C%02d", n - 4)
            default: break
            }
        }

        switch n {
        case 1 ... 9: return String(format: "A%02d", n)
        case 10: return "X01"
        case 11 ... 14: return String(format: "B%02d", n - 10)
        default: return nil
        }
    }

    private static func deduplicated(_ codes: [String]) -> [String] {
        var seen = Set<String>()
        return codes.filter { seen.insert($0).inserted }
    }

    private func findOrCreateCourse(name: String, instructor: String, context: ModelContext) -> Course {
        let all = (try? context.fetch(FetchDescriptor<Course>())) ?? []
        if let existing = all.first(where: { $0.name == name }) {
            if !instructor.isEmpty { existing.instructor = instructor }
            return existing
        }
        let colors = ColorHelper.courseColors
        let colorHex = colors[abs(name.hashValue) % colors.count].hex
        let course = Course(name: name, instructor: instructor, colorHex: colorHex, credits: 3)
        context.insert(course)
        return course
    }

    // MARK: - SwiftData

    func loadSessions(context: ModelContext) {
        let descriptor = FetchDescriptor<ClassSession>()
        sessions = (try? context.fetch(descriptor)) ?? []

        let nonTimedDescriptor = FetchDescriptor<NonTimedScheduleEntry>()
        let entries = (try? context.fetch(nonTimedDescriptor)) ?? []
        nonTimedItems = entries
            .map {
                NonTimedScheduleItem(
                    id: String(describing: $0.persistentModelID),
                    day: $0.dayOfWeek,
                    periodLabel: $0.periodLabel,
                    name: $0.name,
                    classroom: $0.classroom,
                    teacher: $0.teacher,
                    syllabusURL: $0.syllabusURL
                )
            }
            .sorted {
                let lhsDay = $0.day?.rawValue ?? Int.max
                let rhsDay = $1.day?.rawValue ?? Int.max
                if lhsDay == rhsDay {
                    return $0.name < $1.name
                }
                return lhsDay < rhsDay
            }
    }

    func sessionsFor(day: DayOfWeek) -> [ClassSession] {
        sessions.filter { $0.dayOfWeek == day }
    }

    var visibleDays: [DayOfWeek] {
        let hasSaturdayTimed = sessions.contains { $0.dayOfWeek == .saturday }
        let hasSaturdayNonTimed = nonTimedItems.contains { $0.day == .saturday }
        if hasSaturdayTimed || hasSaturdayNonTimed {
            return DayOfWeek.allCases
        }
        return DayOfWeek.allCases.filter { !$0.isSaturday }
    }

    func visibleGridPeriods() -> [PeriodDefinition] {
        let weekdayCodes = Self.weekdayPeriods.map(\.code)
        let saturdayCodes = Self.saturdayPeriods.map(\.code)

        let weekdayMax = sessions
            .filter { !$0.dayOfWeek.isSaturday }
            .compactMap { weekdayCodes.firstIndex(of: $0.periodCode) }
            .max()
        let saturdayMax = sessions
            .filter { $0.dayOfWeek.isSaturday }
            .compactMap { saturdayCodes.firstIndex(of: $0.periodCode) }
            .max()

        var codes: [String] = []
        if let weekdayMax {
            codes.append(contentsOf: Array(weekdayCodes[0 ... weekdayMax]))
        }
        if let saturdayMax {
            for code in saturdayCodes[0 ... saturdayMax] where !codes.contains(code) {
                codes.append(code)
            }
        }

        let defsByCode = Dictionary(uniqueKeysWithValues: Self.gridPeriods.map { ($0.code, $0) })
        let defs = codes.compactMap { defsByCode[$0] }
        return defs.isEmpty ? Self.weekdayPeriods : defs
    }

    func sessions(for day: DayOfWeek, period: String) -> [ClassSession] {
        sessions
            .filter { $0.dayOfWeek == day && $0.periodCode == period }
            .sorted { lhs, rhs in
                let lhsHasCourse = lhs.course != nil
                let rhsHasCourse = rhs.course != nil
                if lhsHasCourse != rhsHasCourse {
                    return lhsHasCourse && !rhsHasCourse
                }
                return (lhs.course?.name ?? "") < (rhs.course?.name ?? "")
            }
    }

    func session(for day: DayOfWeek, period: String) -> ClassSession? {
        sessions(for: day, period: period).first
    }

    func todaySessions() -> [ClassSession] {
        guard let today = DayOfWeek.from(date: Date()) else { return [] }
        let order = Dictionary(uniqueKeysWithValues: Self.periods(for: today).enumerated().map { ($1.code, $0) })
        return sessionsFor(day: today).sorted {
            let lhs = order[$0.periodCode] ?? Int.max
            let rhs = order[$1.periodCode] ?? Int.max
            if lhs == rhs {
                return ($0.course?.name ?? "") < ($1.course?.name ?? "")
            }
            return lhs < rhs
        }
    }

    func nonTimedItems(for day: DayOfWeek?) -> [NonTimedScheduleItem] {
        nonTimedItems.filter { $0.day == day || $0.day == nil }
    }

    func deleteSession(_ session: ClassSession, context: ModelContext) {
        context.delete(session)
        loadSessions(context: context)
    }
}
