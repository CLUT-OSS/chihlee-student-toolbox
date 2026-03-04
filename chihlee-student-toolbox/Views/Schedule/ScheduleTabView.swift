import SwiftUI
import SwiftData

struct ScheduleTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthViewModel.self) private var auth
    @AppStorage("scheduleShowNonTimedItems") private var showNonTimedItems = true
    @State private var viewModel = ScheduleViewModel()
    @State private var showSyncError = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("檢視模式", selection: $viewModel.showWeekView) {
                    Text("整週").tag(true)
                    Text("今日").tag(false)
                }
                .pickerStyle(.segmented)
                .padding()

                if viewModel.showWeekView {
                    TimetableGridView(viewModel: viewModel, showNonTimedItems: showNonTimedItems)
                } else {
                    TodayScheduleView(viewModel: viewModel, showNonTimedItems: showNonTimedItems)
                        .refreshable {
                            await syncSchedule()
                        }
                }

                #if DEBUG
                if let summary = viewModel.lastSyncSummary {
                    Text(summary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 6)
                }
                #endif
            }
            .navigationTitle("課表")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await syncSchedule()
                        }
                    } label: {
                        if viewModel.isSyncing {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("同步課表", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(viewModel.isSyncing)
                }
            }
            .alert("同步失敗", isPresented: $showSyncError) {
                Button("確定", role: .cancel) {}
            } message: {
                Text(viewModel.syncError ?? "")
            }
            .task {
                viewModel.loadSessions(context: modelContext)
                if viewModel.sessions.isEmpty {
                    await syncSchedule()
                }
            }
        }
    }

    private func syncSchedule() async {
        await viewModel.syncFromAPI(token: auth.wrapperToken ?? "", context: modelContext)
        if viewModel.syncError != nil { showSyncError = true }
    }
}

#if DEBUG
#Preview {
    ScheduleTabView()
        .modelContainer(PreviewSampleData.container)
        .environment(AuthViewModel())
}
#endif
