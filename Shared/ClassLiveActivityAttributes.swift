import ActivityKit
import Foundation

struct ClassLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phase: ClassPhase
        var courseName: String
        var classroom: String
        var teacher: String
        var classStart: Date
        var classEnd: Date
        var phaseStart: Date
        var phaseEnd: Date
        var nextCourseName: String?
        var nextStart: Date?
        var nextClassroom: String?
    }

    enum ClassPhase: String, Codable, Hashable {
        case countdown
        case inClass
    }

    var sessionID: String
    var courseName: String
    var classroom: String
    var teacher: String
    var classStart: Date
    var classEnd: Date
}
