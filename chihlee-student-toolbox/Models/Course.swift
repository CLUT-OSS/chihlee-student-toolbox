import Foundation
import SwiftData

@Model
final class Course {
    var name: String
    var instructor: String
    var colorHex: String
    var credits: Int

    @Relationship(deleteRule: .cascade, inverse: \ClassSession.course)
    var sessions: [ClassSession] = []

    @Relationship(deleteRule: .cascade, inverse: \Assignment.course)
    var assignments: [Assignment] = []

    @Relationship(deleteRule: .cascade, inverse: \AttendanceRecord.course)
    var attendanceRecords: [AttendanceRecord] = []

    init(
        name: String = "",
        instructor: String = "",
        colorHex: String = "#007AFF",
        credits: Int = 3
    ) {
        self.name = name
        self.instructor = instructor
        self.colorHex = colorHex
        self.credits = credits
    }
}
