import SwiftUI

struct DlcEventRow: View {
    let event: DlcCalendarEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .foregroundStyle(.purple)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.displaySubject)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)

                if let courseLine = courseLineText {
                    Text(courseLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    if shouldShowSourceTag {
                        Text(event.sourceTag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(tagColor.opacity(0.12))
                            .foregroundStyle(tagColor)
                            .clipShape(Capsule())
                    }

                    if let deadline = event.deadlineTime {
                        Text("截止 \(deadline)")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var courseLineText: String? {
        let course = event.courseName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let code = event.classCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !course.isEmpty && !code.isEmpty {
            return "\(course) (\(code))"
        }
        if !course.isEmpty {
            return course
        }
        if !code.isEmpty {
            return code
        }
        return nil
    }

    private var tagColor: Color {
        event.sourceTag == "學校行事曆" ? .blue : .purple
    }

    private var shouldShowSourceTag: Bool {
        event.sourceTag != "學校行事曆"
    }
}
