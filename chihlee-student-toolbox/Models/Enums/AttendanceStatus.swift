import Foundation
import SwiftUI

enum AttendanceStatus: String, Codable, CaseIterable {
    case present = "present"
    case late = "late"
    case sickLeave = "sickLeave"
    case personalLeave = "personalLeave"
    case absent = "absent"

    var label: String {
        switch self {
        case .present: "出席"
        case .late: "遲到"
        case .sickLeave: "病假"
        case .personalLeave: "事假"
        case .absent: "缺席"
        }
    }

    var color: Color {
        switch self {
        case .present: .green
        case .late: .orange
        case .sickLeave: .blue
        case .personalLeave: .purple
        case .absent: .red
        }
    }

    /// Whether this status counts as an absence for the 1/3 rule
    var countsAsAbsence: Bool {
        switch self {
        case .present, .late: false
        case .sickLeave, .personalLeave, .absent: true
        }
    }

    /// Map the Chinese status string returned by the eportfolio API
    static func from(apiString: String) -> AttendanceStatus {
        switch apiString {
        case "出席":       return .present
        case "遲到":       return .late
        case "病假":       return .sickLeave
        case "事假":       return .personalLeave
        case "缺席", "曠課": return .absent
        default:           return .absent
        }
    }
}
