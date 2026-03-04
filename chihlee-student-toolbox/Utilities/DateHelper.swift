import Foundation

struct DateHelper {
    static let calendar = Calendar.current
    private static let shortDateStyle = Date.FormatStyle()
        .month(.defaultDigits)
        .day(.defaultDigits)
    private static let monthYearStyle = Date.FormatStyle()
        .year()
        .month(.wide)
        .locale(Locale(identifier: "zh_TW"))
    private static let weekTitleDateStyle = Date.FormatStyle()
        .month(.defaultDigits)
        .day(.defaultDigits)
        .locale(Locale(identifier: "zh_TW"))
    private static let daySectionFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "M/d（E）"
        return formatter
    }()

    static func startOfWeekMonday(for date: Date) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        let dayStart = cal.startOfDay(for: date)
        let weekday = cal.component(.weekday, from: dayStart)
        let mondayOffset = (weekday - 2 + 7) % 7
        return cal.date(byAdding: .day, value: -mondayOffset, to: dayStart) ?? dayStart
    }

    static func weekInterval(for date: Date) -> DateInterval {
        let start = startOfWeekMonday(for: date)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    static func monthInterval(for date: Date) -> DateInterval {
        let components = calendar.dateComponents([.year, .month], from: date)
        let start = calendar.date(from: components) ?? calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    static func days(in interval: DateInterval) -> [Date] {
        var result: [Date] = []
        var current = calendar.startOfDay(for: interval.start)
        let end = calendar.startOfDay(for: interval.end)
        while current < end {
            result.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return result
    }

    /// Generate all dates in the week containing the given date (Monday-based)
    static func weekDates(for date: Date) -> [Date] {
        let monday = startOfWeekMonday(for: date)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    /// Generate a month grid (6 rows x 7 days) for the given date's month
    static func monthGrid(for date: Date) -> [[Date?]] {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday

        guard let range = cal.range(of: .day, in: .month, for: date),
              let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: date))
        else { return [] }

        let firstWeekday = cal.component(.weekday, from: firstOfMonth)
        let offset = (firstWeekday - 2 + 7) % 7

        var grid: [[Date?]] = []
        var dayIndex = -offset

        for _ in 0..<6 {
            var week: [Date?] = []
            for _ in 0..<7 {
                if dayIndex >= 0 && dayIndex < range.count {
                    week.append(cal.date(byAdding: .day, value: dayIndex, to: firstOfMonth))
                } else {
                    week.append(nil)
                }
                dayIndex += 1
            }
            // Skip rows that are completely nil
            if week.contains(where: { $0 != nil }) {
                grid.append(week)
            }
        }
        return grid
    }

    /// Days between now and the given date. Negative means overdue.
    static func daysUntil(_ date: Date) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: date)).day ?? 0
    }

    /// Format a date as "M/d"
    static func shortDate(_ date: Date) -> String {
        date.formatted(shortDateStyle)
    }

    /// Format a date as "yyyy年M月"
    static func monthYearString(_ date: Date) -> String {
        date.formatted(monthYearStyle)
    }

    /// Format a week range title as "M/d - M/d"
    static func weekTitle(for date: Date) -> String {
        let interval = weekInterval(for: date)
        guard let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) else {
            return shortDate(interval.start)
        }
        return "\(interval.start.formatted(weekTitleDateStyle)) - \(lastDay.formatted(weekTitleDateStyle))"
    }

    /// Format a month title as "yyyy年M月"
    static func monthTitle(for date: Date) -> String {
        date.formatted(monthYearStyle)
    }

    /// Format day section title as "M/d（E）"
    static func daySectionTitle(_ date: Date) -> String {
        daySectionFormatter.string(from: date)
    }

    /// Check if two dates are on the same calendar day
    static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    /// Format time as "HH:mm"
    static func timeString(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }

    /// Dates for a range of months centered on current month
    static func datesInRange(monthsBack: Int = 3, monthsForward: Int = 3) -> [Date] {
        let today = Date()
        guard let start = calendar.date(byAdding: .month, value: -monthsBack, to: today),
              let end = calendar.date(byAdding: .month, value: monthsForward, to: today)
        else { return [] }

        var dates: [Date] = []
        var current = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)

        while current <= endDay {
            dates.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return dates
    }
}
