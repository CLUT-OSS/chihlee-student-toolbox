import Foundation
import SwiftData

@Model
final class Assignment {
    var title: String
    var assignmentDescription: String
    var dueDate: Date
    var statusRaw: String
    var course: Course?

    var status: AssignmentStatus {
        get { AssignmentStatus(rawValue: statusRaw) ?? .incomplete }
        set { statusRaw = newValue.rawValue }
    }

    init(
        title: String = "",
        assignmentDescription: String = "",
        dueDate: Date = Date(),
        status: AssignmentStatus = .incomplete,
        course: Course? = nil
    ) {
        self.title = title
        self.assignmentDescription = assignmentDescription
        self.dueDate = dueDate
        self.statusRaw = status.rawValue
        self.course = course
    }
}
