import SwiftUI

struct TimetableGridView: View {
    let viewModel: ScheduleViewModel
    let showNonTimedItems: Bool

    private var periods: [PeriodDefinition] { viewModel.visibleGridPeriods() }
    private var hasNonTimed: Bool { showNonTimedItems && !viewModel.nonTimedItems.isEmpty }

    var body: some View {
        GeometryReader { geo in
            timetableContent(in: geo.size)
        }
    }

    private func timetableContent(in size: CGSize) -> some View {
        let headerH: CGFloat = 28
        let nonTimedSectionH: CGFloat = hasNonTimed
            ? CGFloat(viewModel.nonTimedItems.count) * 28 + 44
            : 0
        let gridH = size.height - nonTimedSectionH
        let rowH = max(36, (gridH - headerH - 4) / CGFloat(max(periods.count, 1)))

        return VStack(spacing: 0) {
            Grid(alignment: .center, horizontalSpacing: 1, verticalSpacing: 1) {
                // Header row
                GridRow {
                    Text("節次")
                        .font(.caption2)
                        .frame(width: 40, height: headerH)
                    ForEach(viewModel.visibleDays, id: \.rawValue) { day in
                        Text(day.shortName)
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity, minHeight: headerH)
                            .foregroundStyle(isToday(day) ? .blue : .primary)
                    }
                }

                ForEach(periods) { period in
                    GridRow {
                        VStack(spacing: 1) {
                            Text(period.code)
                                .font(.caption2.bold())
                            Text(period.startString)
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 40, height: rowH)

                        ForEach(viewModel.visibleDays, id: \.rawValue) { day in
                            ClassSessionCell(
                                sessions: viewModel.sessions(for: day, period: period.code),
                                isCurrent: isToday(day) && period.isCurrent()
                            )
                            .frame(height: rowH)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)

            if hasNonTimed {
                VStack(alignment: .leading, spacing: 6) {
                    Text("非固定節次")
                        .font(.footnote.bold())
                        .foregroundStyle(.secondary)
                    ForEach(viewModel.nonTimedItems) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(item.day?.shortName ?? "-")
                                .font(.caption.bold())
                                .frame(width: 16, alignment: .center)
                            Text(item.name)
                                .font(.subheadline)
                            Spacer(minLength: 8)
                            Text(item.periodLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
        }
    }

    private func isToday(_ day: DayOfWeek) -> Bool {
        DayOfWeek.from(date: Date()) == day
    }
}
