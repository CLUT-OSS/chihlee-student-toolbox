import SwiftUI

struct MonthCalendarView: View {
    @Bindable var viewModel: HomeworkViewModel
    private let weekdays = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        VStack(spacing: 8) {
            // Month navigation
            HStack {
                Button {
                    withAnimation {
                        viewModel.changeMonth(by: -1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Button {
                    withAnimation {
                        viewModel.changeMonth(by: 1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal)

            // Weekday headers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            // Date grid
            let grid = DateHelper.monthGrid(for: viewModel.displayedMonth)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(Array(grid.joined().enumerated()), id: \.offset) { _, date in
                    if let date {
                        VStack(spacing: 2) {
                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.body)
                            Circle()
                                .fill(viewModel.hasAnyEvent(on: date) ? .blue : .clear)
                                .frame(width: 5, height: 5)
                        }
                        .frame(height: 40)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(DateHelper.isSameDay(date, viewModel.selectedDate)
                                      ? Color.blue.opacity(0.15) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(DateHelper.isSameDay(date, Date()) ? .blue : .clear, lineWidth: 1)
                        )
                        .onTapGesture {
                            viewModel.selectDate(date)
                        }
                    } else {
                        Color.clear.frame(height: 40)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < -50 {
                        viewModel.changeMonth(by: 1)
                    } else if value.translation.width > 50 {
                        viewModel.changeMonth(by: -1)
                    }
                }
        )
    }
}
