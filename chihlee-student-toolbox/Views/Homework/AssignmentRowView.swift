import SwiftUI

struct AssignmentRowView: View {
    let assignment: Assignment
    let viewModel: HomeworkViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Course color dot
            if let course = assignment.course {
                Circle()
                    .fill(ColorHelper.color(from: course.colorHex))
                    .frame(width: 10, height: 10)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(assignment.title)
                    .font(.body.weight(.medium))

                HStack {
                    if let course = assignment.course {
                        Text(course.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    // Due date countdown
                    dueLabel
                }
            }

            // Status icon
            Image(systemName: assignment.status.iconName)
                .foregroundStyle(statusColor)
        }
    }

    private var dueLabel: some View {
        let days = DateHelper.daysUntil(assignment.dueDate)
        let urgency = viewModel.urgencyColor(for: assignment)

        return Group {
            if assignment.status == .submitted {
                Text("已繳交")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else if days < 0 {
                Text("逾期 \(-days) 天")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
            } else if days == 0 {
                Text("今天到期")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
            } else if days == 1 {
                Text("明天到期")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            } else {
                Text("還有 \(days) 天")
                    .font(.caption)
                    .foregroundStyle(urgency == .warning ? .yellow : .secondary)
            }
        }
    }

    private var statusColor: Color {
        switch assignment.status {
        case .incomplete: .gray
        case .inProgress: .orange
        case .submitted: .green
        }
    }
}
