import Foundation

enum AssignmentStatus: String, Codable, CaseIterable {
    case incomplete = "incomplete"
    case inProgress = "inProgress"
    case submitted = "submitted"

    var label: String {
        switch self {
        case .incomplete: "未完成"
        case .inProgress: "進行中"
        case .submitted: "已繳交"
        }
    }

    var iconName: String {
        switch self {
        case .incomplete: "circle"
        case .inProgress: "arrow.trianglehead.clockwise"
        case .submitted: "checkmark.circle.fill"
        }
    }
}
