import Foundation
import SwiftData

@Model
final class AttendanceRecord {
    var date: Date
    var statusRaw: String
    var course: Course?

    var status: AttendanceStatus {
        get { AttendanceStatus(rawValue: statusRaw) ?? .present }
        set { statusRaw = newValue.rawValue }
    }

    init(
        date: Date = Date(),
        status: AttendanceStatus = .present,
        course: Course? = nil
    ) {
        self.date = date
        self.statusRaw = status.rawValue
        self.course = course
    }
}
