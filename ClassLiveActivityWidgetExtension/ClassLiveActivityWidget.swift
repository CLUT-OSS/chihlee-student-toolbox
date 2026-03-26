import ActivityKit
import Foundation
import SwiftUI
import UIKit
import WidgetKit

struct ClassLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClassLiveActivityAttributes.self) { context in
            ClassLiveActivityLockScreenView(context: context)
                .fontDesign(.rounded)
                .activityBackgroundTint(Self.lockScreenBackgroundTint)
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            if context.state.phase == .countdown {
                DynamicIsland {
                    DynamicIslandExpandedRegion(.leading, priority: 2) {
                        CountdownExpandedLeadingView(endDate: context.state.phaseEnd)
                    }
                    DynamicIslandExpandedRegion(.center, priority: 3) {
                        CountdownExpandedCenterView(
                            courseName: context.state.courseName,
                            classroom: context.state.classroom,
                            classStartText: Self.timeString(context.state.classStart)
                        )
                    }
                    DynamicIslandExpandedRegion(.bottom, priority: 2) {
                        CountdownExpandedBottomView(
                            phaseStart: context.state.phaseStart,
                            phaseEnd: context.state.phaseEnd,
                            classStartText: Self.timeString(context.state.classStart)
                        )
                    }
                } compactLeading: {
                    if let compactClassroom = Self.compactClassroomToken(from: context.state) {
                        Text(compactClassroom)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    } else {
                        Text("--")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                } compactTrailing: {
                    CountdownRemainingMinutesText(
                        dateRange: LiveActivityDateRange.between(
                            context.state.phaseStart,
                            context.state.phaseEnd
                        ),
                        prefix: "",
                        tint: .orange
                    )
                } minimal: {
                    CountdownRemainingMinutesText(
                        dateRange: LiveActivityDateRange.between(
                            context.state.phaseStart,
                            context.state.phaseEnd
                        ),
                        prefix: "還有",
                        tint: .orange,
                        display: .minimal
                    )
                }
            } else {
                DynamicIsland {
                    DynamicIslandExpandedRegion(.leading, priority: 3) {
                        InClassExpandedLeadingView(
                            courseName: context.state.courseName,
                            classroom: context.state.classroom
                        )
                    }
                    DynamicIslandExpandedRegion(.trailing, priority: 2) {
                        RemainingRingView(
                            endDate: context.state.phaseEnd
                        )
                    }
                    DynamicIslandExpandedRegion(.bottom, priority: 2) {
                        InClassExpandedBottomView(
                            phaseStart: context.state.phaseStart,
                            phaseEnd: context.state.phaseEnd,
                            nextCourseName: context.state.nextCourseName,
                            nextClassroom: context.state.nextClassroom
                        )
                    }
                } compactLeading: {
                    Image(systemName: "book.fill")
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(.green)
                } compactTrailing: {
                    ShortRemainingMinutesText(
                        dateRange: LiveActivityDateRange.between(
                            context.state.phaseStart,
                            context.state.phaseEnd
                        )
                    )
                } minimal: {
                    ShortRemainingMinutesText(
                        dateRange: LiveActivityDateRange.between(
                            context.state.phaseStart,
                            context.state.phaseEnd
                        ),
                        display: .minimal
                    )
                }
            }
        }
    }

    private static func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private static func minimalClassroomToken(
        from state: ClassLiveActivityAttributes.ContentState
    ) -> String? {
        islandLocationToken(from: state.classroom, maxLength: 3)
    }

    private static func compactClassroomToken(
        from state: ClassLiveActivityAttributes.ContentState
    ) -> String? {
        islandLocationToken(from: state.classroom, maxLength: 4)
    }

    private static func islandLocationToken(from classroom: String, maxLength: Int) -> String? {
        let trimmed = classroom.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let asciiAlphanumerics = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        let alphanumerics = String(trimmed.unicodeScalars.filter(asciiAlphanumerics.contains))
        let normalized = alphanumerics.isEmpty ? trimmed.replacingOccurrences(of: " ", with: "") : alphanumerics
        guard !normalized.isEmpty else { return nil }
        return String(normalized.prefix(maxLength))
    }

    private static var lockScreenBackgroundTint: Color {
        Color(UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(
                    red: 0.13,
                    green: 0.16,
                    blue: 0.20,
                    alpha: 0.86
                )
            }
            return UIColor.white.withAlphaComponent(0.92)
        })
    }
}

private enum LiveActivityDateRange {
    static func between(_ first: Date, _ second: Date) -> ClosedRange<Date> {
        let lower = min(first, second)
        let upper = max(first, second)
        return lower...upper
    }

    static func remaining(until endDate: Date, now: Date = .now) -> ClosedRange<Date> {
        now...max(now, endDate)
    }
}

private struct ShortRemainingMinutesText: View {
    let dateRange: ClosedRange<Date>
    var display: TimerDisplay = .compact

    var body: some View {
        FixedWidthTimerText(
            dateRange: dateRange,
            font: display.timerFont,
            uiFont: display.uiFont,
            minimumScaleFactor: 0.7
        )
    }
}

private struct CountdownRemainingMinutesText: View {
    let dateRange: ClosedRange<Date>
    let prefix: String
    let tint: Color
    var display: TimerDisplay = .compact

    var body: some View {
        HStack(spacing: 1) {
            if !prefix.isEmpty {
                Text(prefix)
                    .font(display.prefixFont)
            }
            FixedWidthTimerText(
                dateRange: dateRange,
                font: display.timerFont,
                uiFont: display.uiFont,
                minimumScaleFactor: 0.7
            )
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .foregroundStyle(tint)
    }
}

private enum TimerDisplay {
    case compact
    case minimal

    var timerFont: Font {
        switch self {
        case .compact:
            return .system(size: 15, weight: .bold, design: .rounded)
        case .minimal:
            return .system(size: 22, weight: .bold, design: .rounded)
        }
    }

    var prefixFont: Font {
        switch self {
        case .compact:
            return .system(size: 14, weight: .semibold, design: .rounded)
        case .minimal:
            return .system(size: 13, weight: .semibold, design: .rounded)
        }
    }

    var uiFont: UIFont {
        switch self {
        case .compact:
            return UIFont.monospacedDigitSystemFont(ofSize: 15, weight: .bold)
        case .minimal:
            return UIFont.monospacedDigitSystemFont(ofSize: 22, weight: .bold)
        }
    }
}

private struct FixedWidthTimerText: View {
    let dateRange: ClosedRange<Date>
    let font: Font
    let uiFont: UIFont
    let minimumScaleFactor: CGFloat
    let alignment: Alignment

    init(
        dateRange: ClosedRange<Date>,
        font: Font,
        uiFont: UIFont,
        minimumScaleFactor: CGFloat = 0.7,
        alignment: Alignment = .center
    ) {
        self.dateRange = dateRange
        self.font = font
        self.uiFont = uiFont
        self.minimumScaleFactor = minimumScaleFactor
        self.alignment = alignment
    }

    var body: some View {
        Group {
            if dateRange.upperBound > .now {
                Text(timerInterval: dateRange, countsDown: true, showsHours: false)
            } else {
                Text("00:00")
            }
        }
        .font(font.monospacedDigit())
        .frame(width: templateWidth, alignment: alignment)
        .lineLimit(1)
        .minimumScaleFactor(minimumScaleFactor)
    }

    private var templateWidth: CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: uiFont]
        return (template as NSString).size(withAttributes: attributes).width
    }

    private var template: String {
        let duration = max(0, dateRange.upperBound.timeIntervalSince(dateRange.lowerBound))
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct InClassExpandedLeadingView: View {
    let courseName: String
    let classroom: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(courseName)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .allowsTightening(true)

            HStack(spacing: 6) {
                Circle()
                    .fill(.green)
                    .frame(width: 7, height: 7)
                Text("\(classroom.isEmpty ? "--" : classroom) • 進行中")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)
            }
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
        }
        .padding(.leading, 8)
        .padding(.top, 6)
        .padding(.trailing, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RemainingRingView: View {
    let endDate: Date

    var body: some View {
        FixedWidthTimerText(
            dateRange: LiveActivityDateRange.remaining(until: endDate),
            font: .system(size: 22, weight: .bold, design: .rounded),
            uiFont: UIFont.monospacedDigitSystemFont(ofSize: 22, weight: .bold),
            minimumScaleFactor: 0.75,
            alignment: .trailing
        )
        .frame(width: 72, alignment: .trailing)
        .frame(maxHeight: .infinity, alignment: .center)
    }
}

private struct InClassExpandedBottomView: View {
    let phaseStart: Date
    let phaseEnd: Date
    let nextCourseName: String?
    let nextClassroom: String?

    var body: some View {
        let phaseRange = LiveActivityDateRange.between(phaseStart, phaseEnd)

        VStack(alignment: .leading, spacing: 8) {
            ProgressView(timerInterval: phaseRange, countsDown: false)
                .tint(.green)
                .labelsHidden()

            if let nextCourseName, !nextCourseName.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("下一堂")
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                    Spacer(minLength: 10)
                    Text(nextCourseName + (nextClassroom.flatMap { $0.isEmpty ? nil : " • \($0)" } ?? ""))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .truncationMode(.tail)
                        .foregroundStyle(.primary)
                }
                .font(.system(.headline, design: .rounded))
                .padding(.trailing, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CountdownExpandedLeadingView: View {
    let endDate: Date

    var body: some View {
        VStack(spacing: 0) {
            FixedWidthTimerText(
                dateRange: LiveActivityDateRange.remaining(until: endDate),
                font: .system(size: 30, weight: .bold, design: .rounded),
                uiFont: UIFont.monospacedDigitSystemFont(ofSize: 30, weight: .bold),
                minimumScaleFactor: 0.55,
                alignment: .center
            )
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .foregroundStyle(.orange)
        .frame(width: 92, height: 92)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.orange.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.orange.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct CountdownExpandedCenterView: View {
    let courseName: String
    let classroom: String
    let classStartText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("下一堂課")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.secondary)
            Text(courseName)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .allowsTightening(true)
            Text("\(classroom.isEmpty ? "--" : classroom) • \(classStartText) 開始")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CountdownExpandedBottomView: View {
    let phaseStart: Date
    let phaseEnd: Date
    let classStartText: String

    var body: some View {
        let phaseRange = LiveActivityDateRange.between(phaseStart, phaseEnd)

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("現在")
                Text(Date(), style: .time)
                Spacer()
                Text("開始 \(classStartText)")
            }
            .font(.system(.caption2, design: .rounded).weight(.semibold))
            .foregroundStyle(.secondary)

            ProgressView(timerInterval: phaseRange, countsDown: false)
                .progressViewStyle(.linear)
                .tint(.orange)
                .labelsHidden()
                .frame(height: 6)
                .padding(.horizontal, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

private struct ClassLiveActivityLockScreenView: View {
    let context: ActivityViewContext<ClassLiveActivityAttributes>
    private let primaryTextColor = Color.primary
    private let secondaryTextColor = Color.secondary

    private var statusTitle: String {
        context.state.phase == .inClass ? "上課中" : "準備上課"
    }

    private var statusColor: Color {
        context.state.phase == .inClass ? .green : .orange
    }

    private var statusPrefix: String {
        context.state.phase == .inClass ? "剩餘" : "倒數"
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            activityContent(showNextClass: true)
            activityContent(showNextClass: false)
        }
    }

    @ViewBuilder
    private func activityContent(showNextClass: Bool) -> some View {
        let phaseRange = LiveActivityDateRange.between(
            context.state.phaseStart,
            context.state.phaseEnd
        )

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 9, height: 9)
                    Text(statusTitle)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(statusColor)
                }
                Spacer(minLength: 8)
                HStack(spacing: 4) {
                    Text(statusPrefix)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(secondaryTextColor)
                    FixedWidthTimerText(
                        dateRange: phaseRange,
                        font: .system(.subheadline, design: .rounded).weight(.semibold),
                        uiFont: UIFont.monospacedDigitSystemFont(ofSize: 15, weight: .semibold),
                        minimumScaleFactor: 0.85,
                        alignment: .trailing
                    )
                        .foregroundStyle(primaryTextColor)
                }
                .lineLimit(1)
            }

            Text(context.state.courseName)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(primaryTextColor)

            ProgressView(timerInterval: phaseRange, countsDown: false)
                .progressViewStyle(.linear)
                .tint(statusColor)
                .labelsHidden()
                .scaleEffect(x: 1, y: 0.9, anchor: .center)

            HStack(spacing: 12) {
                if !context.state.classroom.isEmpty {
                    Label(context.state.classroom, systemImage: "location")
                }
                Label("\(timeString(context.state.classStart)) - \(timeString(context.state.classEnd))", systemImage: "clock")
                if !context.state.teacher.isEmpty {
                    Label(context.state.teacher, systemImage: "person")
                }
            }
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(secondaryTextColor)
            .lineLimit(1)

            if showNextClass,
               let nextCourseName = context.state.nextCourseName,
               let nextStart = context.state.nextStart {
                Divider()
                HStack(spacing: 8) {
                    Text("下一堂")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(.orange)
                    Text(timeString(nextStart))
                        .font(.system(.caption, design: .rounded).monospacedDigit())
                        .foregroundStyle(secondaryTextColor)
                    if let nextClassroom = context.state.nextClassroom, !nextClassroom.isEmpty {
                        Text(nextClassroom)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(secondaryTextColor)
                    }
                    Text(nextCourseName)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(primaryTextColor)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
