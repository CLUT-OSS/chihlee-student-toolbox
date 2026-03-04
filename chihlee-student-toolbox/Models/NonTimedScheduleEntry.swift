import Foundation
import SwiftData

@Model
final class NonTimedScheduleEntry {
    var dayOfWeekRaw: Int?
    var periodLabel: String
    var name: String
    var classroom: String
    var teacher: String
    var syllabusURL: String

    var dayOfWeek: DayOfWeek? {
        get {
            guard let dayOfWeekRaw else { return nil }
            return DayOfWeek(rawValue: dayOfWeekRaw)
        }
        set {
            dayOfWeekRaw = newValue?.rawValue
        }
    }

    init(
        dayOfWeekRaw: Int? = nil,
        periodLabel: String = "",
        name: String = "",
        classroom: String = "",
        teacher: String = "",
        syllabusURL: String = ""
    ) {
        self.dayOfWeekRaw = dayOfWeekRaw
        self.periodLabel = periodLabel
        self.name = name
        self.classroom = classroom
        self.teacher = teacher
        self.syllabusURL = syllabusURL
    }
}
