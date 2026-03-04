import SwiftUI
import SwiftData

struct AttendanceTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthViewModel.self) private var auth
    @State private var viewModel = AttendanceViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoadingAPI {
                    ProgressView("載入中…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.apiError {
                    ContentUnavailableView {
                        Label("載入失敗", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("重試") {
                            Task { await viewModel.loadFromAPI(token: auth.wrapperToken ?? "") }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if viewModel.allRecords.isEmpty {
                    ContentUnavailableView("尚無缺席資料", systemImage: "checkmark.circle")
                } else {
                    mainContent
                }
            }
            .navigationTitle("出缺勤")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.loadFromAPI(token: auth.wrapperToken ?? "") }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoadingAPI)
                }
            }
            .task {
                if viewModel.allRecords.isEmpty {
                    await viewModel.loadFromAPI(token: auth.wrapperToken ?? "")
                }
            }
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                summaryCard
                coursesSection
            }
            .padding()
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(viewModel.totalAbsences)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.red)
                Text("缺曠總計")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }

            Divider()

            if let recent = viewModel.mostRecentAbsence {
                let dateOnly = recent.date.components(separatedBy: ", ").first ?? recent.date
                let status = AttendanceStatus.from(apiString: recent.status)

                VStack(alignment: .leading, spacing: 4) {
                    Text("最近缺曠")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(recent.courseTitle ?? "未知課程")
                                .font(.subheadline.bold())
                            Text("\(dateOnly)　\(recent.period)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(recent.status)
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(status.color.opacity(0.15))
                            .foregroundStyle(status.color)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Course Buttons

    private var coursesSection: some View {
        VStack(spacing: 10) {
            ForEach(viewModel.absencesByCourse) { group in
                NavigationLink {
                    CourseAbsenceDetailView(group: group)
                } label: {
                    HStack {
                        Text(group.courseTitle)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(group.count) 缺曠")
                            .font(.subheadline.bold())
                            .foregroundStyle(group.count >= 3 ? .red : .orange)
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    AttendanceTabView()
        .modelContainer(PreviewSampleData.container)
        .environment(AuthViewModel())
}
#endif
