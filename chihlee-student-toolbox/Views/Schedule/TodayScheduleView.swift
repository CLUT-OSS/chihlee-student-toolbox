import SwiftUI

struct TodayScheduleView: View {
    let viewModel: ScheduleViewModel
    let showNonTimedItems: Bool

    var body: some View {
        let sessions = viewModel.todaySessions()
        let today = DayOfWeek.from(date: Date())
        let nonTimedToday = showNonTimedItems ? viewModel.nonTimedItems(for: today) : []
        let periods = today.map { ScheduleViewModel.periods(for: $0) } ?? ScheduleViewModel.weekdayPeriods

        List {
            if sessions.isEmpty && nonTimedToday.isEmpty {
                ContentUnavailableView("今天沒有課程", systemImage: "calendar.badge.checkmark", description: Text("享受你的休息時間吧！"))
            } else {
                ForEach(sessions, id: \.persistentModelID) { session in
                    let period = periods.first { $0.code == session.periodCode }
                    HStack(spacing: 12) {
                        // Time column
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(period?.startString ?? "")
                                .font(.caption.bold())
                            Text(period?.endString ?? "")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 50)

                        // Color bar
                        if let course = session.course {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(ColorHelper.color(from: course.colorHex))
                                .frame(width: 4)
                        }

                        // Course info
                        VStack(alignment: .leading, spacing: 4) {
                            if let url = URL(string: session.syllabusURL), !session.syllabusURL.isEmpty {
                                Link(destination: url) {
                                    Text(session.course?.name ?? "")
                                        .font(.headline)
                                }
                                .foregroundStyle(.primary)
                            } else {
                                Text(session.course?.name ?? "")
                                    .font(.headline)
                            }
                            HStack {
                                Text("教室：\(session.classroom)")
                                Spacer()
                                Text("導師：\(session.course?.instructor ?? "")")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(
                        period?.isCurrent() == true
                        ? Color.blue.opacity(0.1)
                        : Color.clear
                    )
                }

                if !nonTimedToday.isEmpty {
                    Section("非固定節次") {
                        ForEach(nonTimedToday) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                if let url = URL(string: item.syllabusURL), !item.syllabusURL.isEmpty {
                                    Link(destination: url) {
                                        Text(item.name)
                                            .font(.headline)
                                    }
                                    .foregroundStyle(.primary)
                                } else {
                                    Text(item.name)
                                        .font(.headline)
                                }

                                HStack {
                                    if !item.classroom.isEmpty {
                                        Label(item.classroom, systemImage: "mappin")
                                    }
                                    if !item.teacher.isEmpty {
                                        Label(item.teacher, systemImage: "person")
                                    }
                                    Spacer()
                                    Text(item.periodLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }
}
