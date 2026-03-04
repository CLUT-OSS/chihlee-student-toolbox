import Foundation
import SwiftData

@Model
final class Student {
    var name: String
    var studentID: String
    var department: String
    var grade: Int
    var semesterStart: Date
    var semesterEnd: Date

    init(
        name: String = "",
        studentID: String = "",
        department: String = "",
        grade: Int = 1,
        semesterStart: Date = Date(),
        semesterEnd: Date = Calendar.current.date(byAdding: .month, value: 4, to: Date()) ?? Date()
    ) {
        self.name = name
        self.studentID = studentID
        self.department = department
        self.grade = grade
        self.semesterStart = semesterStart
        self.semesterEnd = semesterEnd
    }
}
