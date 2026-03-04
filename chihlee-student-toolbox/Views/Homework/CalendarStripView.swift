import SwiftUI

struct CalendarStripView: View {
    @Bindable var viewModel: HomeworkViewModel
    private let calendar = DateHelper.calendar
    private let weekdayStyle = Date.FormatStyle()
        .weekday(.short)
        .locale(Locale(identifier: "zh_TW"))

    var body: some View {
        let dates = DateHelper.weekDates(for: viewModel.weekAnchorDate)

        VStack(spacing: 10) {
            HStack {
                Button {
                    withAnimation {
                        viewModel.changeWeek(by: -1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }

                Spacer()

                Button {
                    withAnimation {
                        viewModel.changeWeek(by: 1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal)

            HStack(spacing: 8) {
                ForEach(dates, id: \.self) { date in
                    VStack(spacing: 4) {
                        Text(weekdayString(date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(calendar.component(.day, from: date))")
                            .font(.body.bold())
                        Circle()
                            .fill(viewModel.hasAnyEvent(on: date) ? .blue : .clear)
                            .frame(width: 6, height: 6)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(DateHelper.isSameDay(date, viewModel.selectedDate)
                                  ? Color.blue.opacity(0.15)
                                  : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(DateHelper.isSameDay(date, Date()) ? .blue : .clear, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectDate(date)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    if value.translation.width < -40 {
                        viewModel.changeWeek(by: 1)
                    } else if value.translation.width > 40 {
                        viewModel.changeWeek(by: -1)
                    }
                }
        )
    }

    private func weekdayString(_ date: Date) -> String {
        date.formatted(weekdayStyle)
    }
}
