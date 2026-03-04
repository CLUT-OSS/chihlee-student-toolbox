import Foundation
import SwiftData

@Model
final class ClassSession {
    var course: Course?
    var dayOfWeekRaw: Int
    var periodCode: String
    var classroom: String
    var syllabusURL: String

    var dayOfWeek: DayOfWeek {
        get { DayOfWeek(rawValue: dayOfWeekRaw) ?? .monday }
        set { dayOfWeekRaw = newValue.rawValue }
    }

    init(
        course: Course? = nil,
        dayOfWeek: DayOfWeek = .monday,
        periodCode: String = "A01",
        classroom: String = "",
        syllabusURL: String = ""
    ) {
        self.course = course
        self.dayOfWeekRaw = dayOfWeek.rawValue
        self.periodCode = periodCode
        self.classroom = classroom
        self.syllabusURL = syllabusURL
    }
}
