import Foundation

enum DayOfWeek: Int, Codable, CaseIterable, Comparable {
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var shortName: String {
        switch self {
        case .monday: "一"
        case .tuesday: "二"
        case .wednesday: "三"
        case .thursday: "四"
        case .friday: "五"
        case .saturday: "六"
        }
    }

    var fullName: String {
        switch self {
        case .monday: "星期一"
        case .tuesday: "星期二"
        case .wednesday: "星期三"
        case .thursday: "星期四"
        case .friday: "星期五"
        case .saturday: "星期六"
        }
    }

    var isSaturday: Bool { self == .saturday }

    static func from(date: Date) -> DayOfWeek? {
        let weekday = Calendar.current.component(.weekday, from: date)
        return DayOfWeek(rawValue: weekday)
    }

    /// Map the Chinese weekday string returned by eportfolio API.
    /// Handles both short form ("一") and full form ("星期一").
    static func from(apiString: String) -> DayOfWeek? {
        let normalized = apiString
            .applyingTransform(.fullwidthToHalfwidth, reverse: false)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
            ?? apiString
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: " ", with: "")
                .uppercased()

        let compact = normalized
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "星期", with: "")
            .replacingOccurrences(of: "週", with: "")
            .replacingOccurrences(of: "周", with: "")
            .replacingOccurrences(of: "禮拜", with: "")
            .replacingOccurrences(of: "礼拜", with: "")
            .uppercased()

        if compact == "1" || compact.contains("一") || compact.contains("MON") { return .monday }
        if compact == "2" || compact.contains("二") || compact.contains("TUE") { return .tuesday }
        if compact == "3" || compact.contains("三") || compact.contains("WED") { return .wednesday }
        if compact == "4" || compact.contains("四") || compact.contains("THU") { return .thursday }
        if compact == "5" || compact.contains("五") || compact.contains("FRI") { return .friday }
        if compact == "6" || compact.contains("六") || compact.contains("SAT") { return .saturday }
        return nil
    }

    static func < (lhs: DayOfWeek, rhs: DayOfWeek) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
