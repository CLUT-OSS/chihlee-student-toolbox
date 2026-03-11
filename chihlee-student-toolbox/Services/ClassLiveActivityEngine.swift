import Foundation

struct ClassLiveActivityTimelineEntry: Equatable {
    let sessionID: String
    let courseName: String
    let classroom: String
    let teacher: String
    let classStart: Date
    let classEnd: Date
}

struct ClassLiveActivitySnapshot: Equatable {
    let sessionID: String
    let phase: ClassLiveActivityAttributes.ClassPhase
    let courseName: String
    let classroom: String
    let teacher: String
    let classStart: Date
    let classEnd: Date
    let phaseStart: Date
    let phaseEnd: Date
    let nextCourseName: String?
    let nextStart: Date?
    let nextClassroom: String?
}

enum ClassLiveActivityEngine {
    static let preClassLeadTime: TimeInterval = 15 * 60

    @MainActor
    static func timelineEntries(now: Date, sessions: [ClassSession], calendar: Calendar = .current) -> [ClassLiveActivityTimelineEntry] {
        guard let today = DayOfWeek.from(date: now) else { return [] }

        let periods = ScheduleViewModel.periods(for: today)
        let periodMap = Dictionary(uniqueKeysWithValues: periods.map { ($0.code, $0) })
        let startOfDay = calendar.startOfDay(for: now)

        let entries = sessions.compactMap { session -> ClassLiveActivityTimelineEntry? in
            guard session.dayOfWeek == today,
                  let period = periodMap[session.periodCode],
                  let start = calendar.date(bySettingHour: period.startHour, minute: period.startMinute, second: 0, of: startOfDay),
                  let end = calendar.date(bySettingHour: period.endHour, minute: period.endMinute, second: 0, of: startOfDay)
            else {
                return nil
            }

            let courseName = (session.course?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let teacher = (session.course?.instructor ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedCourseName = courseName.isEmpty ? "未命名課程" : courseName
            let normalizedClassroom = session.classroom.trimmingCharacters(in: .whitespacesAndNewlines)

            let id = [
                normalizedCourseName,
                String(start.timeIntervalSince1970),
                String(end.timeIntervalSince1970),
                normalizedClassroom,
            ].joined(separator: "|")

            return ClassLiveActivityTimelineEntry(
                sessionID: id,
                courseName: normalizedCourseName,
                classroom: normalizedClassroom,
                teacher: teacher,
                classStart: start,
                classEnd: end
            )
        }

        return entries.sorted {
            if $0.classStart == $1.classStart {
                return $0.courseName < $1.courseName
            }
            return $0.classStart < $1.classStart
        }
    }

    static func snapshot(
        now: Date,
        entries: [ClassLiveActivityTimelineEntry],
        preClassLeadTime: TimeInterval = preClassLeadTime
    ) -> ClassLiveActivitySnapshot? {
        let sorted = entries.sorted {
            if $0.classStart == $1.classStart {
                return $0.courseName < $1.courseName
            }
            return $0.classStart < $1.classStart
        }

        guard let activeIndex = sorted.firstIndex(where: { entry in
            let preClassStart = entry.classStart.addingTimeInterval(-preClassLeadTime)
            return now >= preClassStart && now < entry.classEnd
        }) else {
            return nil
        }

        let entry = sorted[activeIndex]
        let phase: ClassLiveActivityAttributes.ClassPhase = now < entry.classStart ? .countdown : .inClass
        let phaseStart: Date = phase == .countdown
            ? entry.classStart.addingTimeInterval(-preClassLeadTime)
            : entry.classStart
        let phaseEnd: Date = phase == .countdown ? entry.classStart : entry.classEnd

        let next = sorted[(activeIndex + 1)...].first(where: { $0.classStart >= entry.classEnd })

        return ClassLiveActivitySnapshot(
            sessionID: entry.sessionID,
            phase: phase,
            courseName: entry.courseName,
            classroom: entry.classroom,
            teacher: entry.teacher,
            classStart: entry.classStart,
            classEnd: entry.classEnd,
            phaseStart: phaseStart,
            phaseEnd: phaseEnd,
            nextCourseName: next?.courseName,
            nextStart: next?.classStart,
            nextClassroom: next?.classroom
        )
    }
}
