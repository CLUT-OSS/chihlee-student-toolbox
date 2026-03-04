import SwiftUI

struct CourseAbsenceDetailView: View {
    let group: AttendanceViewModel.CourseAbsenceGroup

    var body: some View {
        List(group.records) { record in
            let status = AttendanceStatus.from(apiString: record.status)
            let dateOnly = record.date.components(separatedBy: ", ").first ?? record.date

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dateOnly)
                        .font(.body)
                    Text(record.period)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(record.status)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(status.color.opacity(0.15))
                    .foregroundStyle(status.color)
                    .clipShape(Capsule())
            }
            .padding(.vertical, 2)
        }
        .navigationTitle(group.courseTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
