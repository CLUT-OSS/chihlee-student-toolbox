import SwiftUI
import SwiftData

struct HomeworkTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthViewModel.self) private var auth
    @State private var viewModel = HomeworkViewModel()
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("檢視模式", selection: $viewModel.showMonthView) {
                    Text("週曆").tag(false)
                    Text("月曆").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .onChange(of: viewModel.showMonthView) { _, isMonth in
                    viewModel.setViewMode(isMonth: isMonth)
                }

                if viewModel.showMonthView {
                    MonthCalendarView(viewModel: viewModel)
                } else {
                    CalendarStripView(viewModel: viewModel)
                }

                Divider()

                let sections = viewModel.groupedSectionsForCurrentScope()

                List {
                    if viewModel.isDayScope {
                        Section {
                            HStack {
                                Text("已篩選：\(viewModel.selectedDayFilterTitle)")
                                    .font(.subheadline)
                                Spacer()
                                Button("清除") {
                                    viewModel.resetToRangeScope()
                                }
                                .buttonStyle(.borderless)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }

                    if sections.isEmpty {
                        ContentUnavailableView(
                            "沒有待辦事項",
                            systemImage: "checkmark.circle",
                            description: Text(viewModel.emptyStateDescription)
                        )
                    } else {
                        ForEach(sections) { section in
                            Section {
                                let dayAssignments = section.assignments
                                let dayEvents = section.events

                                if !dayAssignments.isEmpty {
                                    ForEach(dayAssignments, id: \.persistentModelID) { assignment in
                                        NavigationLink {
                                            AssignmentDetailView(assignment: assignment) {
                                                viewModel.loadAssignments(context: modelContext)
                                            }
                                        } label: {
                                            AssignmentRowView(assignment: assignment, viewModel: viewModel)
                                        }
                                    }
                                    .onDelete { offsets in
                                        for i in offsets {
                                            viewModel.deleteAssignment(dayAssignments[i], context: modelContext)
                                        }
                                    }
                                }

                                if !dayEvents.isEmpty {
                                    if !dayAssignments.isEmpty {
                                        Text("行事曆事件")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    ForEach(dayEvents) { event in
                                        DlcEventRow(event: event)
                                    }
                                }
                            }
                            header: {
                                Text(section.title)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button {
                        viewModel.resetToRangeScope()
                    } label: {
                        Text(viewModel.currentRangeTitle)
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("重設為範圍檢視")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await refreshHomework()
                        }
                    } label: {
                        if isRefreshing {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isRefreshing)
                }
            }
            .task {
                await refreshHomework()
                viewModel.setViewMode(isMonth: viewModel.showMonthView)
            }
        }
    }

    @MainActor
    private func refreshHomework() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        viewModel.loadAssignments(context: modelContext)
        await viewModel.fetchDlcEvents(token: auth.wrapperToken ?? "")
    }
}

#if DEBUG
#Preview {
    HomeworkTabView()
        .modelContainer(PreviewSampleData.container)
        .environment(AuthViewModel())
}
#endif
