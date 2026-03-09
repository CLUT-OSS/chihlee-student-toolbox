import SwiftUI

struct LeaveApplicationView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var viewModel = LeaveApplicationViewModel()
    @FocusState private var isLeaveReasonFocused: Bool

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("請假模式", selection: subBinding) {
                    Text("申請請假").tag(LeaveApplicationViewModel.SubView.apply)
                    Text("請假紀錄").tag(LeaveApplicationViewModel.SubView.records)
                }
                .pickerStyle(.segmented)

                if viewModel.sub == .apply {
                    applyFlow
                } else {
                    recordsFlow
                }
            }
            .padding()
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .simultaneousGesture(
            TapGesture().onEnded {
                isLeaveReasonFocused = false
            }
        )
        .navigationTitle("請假申請")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: auth.wrapperToken) {
            guard viewModel.sub == .apply else { return }
            if viewModel.sdate.isEmpty {
                await viewModel.updateStartDate(formatDate(Date()), token: auth.wrapperToken)
            } else if viewModel.availableCourses.isEmpty {
                await viewModel.loadCoursesIfNeeded(token: auth.wrapperToken)
            }
        }
    }

    private var subBinding: Binding<LeaveApplicationViewModel.SubView> {
        Binding(
            get: { viewModel.sub },
            set: { newValue in
                Task {
                    await viewModel.switchSub(newValue, token: auth.wrapperToken)
                }
            }
        )
    }

    // MARK: - Apply Flow

    @ViewBuilder
    private var applyFlow: some View {
        switch viewModel.step {
        case .form:
            formStep
        case .confirm:
            confirmStep
        case .success:
            successStep
        }
    }

    private var formStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            DatePicker(
                "起始日期 *",
                selection: startDateBinding,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)

            DatePicker(
                "結束日期",
                selection: endDateBinding,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)

            typeSelector

            if !viewModel.sdate.isEmpty {
                courseSelector
            }

            leaveReasonInput

            if let error = viewModel.applyError, !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                viewModel.goToConfirm()
            } label: {
                Text("下一步：確認內容 →")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .disabled(!viewModel.canProceedToConfirm)
            .buttonStyle(PrimaryActionButtonStyle(enabled: viewModel.canProceedToConfirm))
        }
    }

    private var confirmStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("← 返回修改") {
                viewModel.backToForm()
            }
            .font(.subheadline.weight(.medium))
            .buttonStyle(.plain)

            summaryRow(title: "假別", value: viewModel.selectedTypeOption.label, color: leaveTypeColor(for: viewModel.selectedTypeOption.value))
            summaryRow(title: "日期", value: displayDateRange(start: viewModel.sdate, end: viewModel.edate))
            summaryRow(title: "節次", value: "\(viewModel.selectedCourses.count)")
            VStack(alignment: .leading, spacing: 6) {
                Text("請假原因")
                    .font(.subheadline.weight(.semibold))
                Text(displayText(viewModel.leaveReason))
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("請假課程")
                    .font(.subheadline.weight(.semibold))
                ForEach(viewModel.selectedCourses) { course in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(course.courseName)
                            .font(.subheadline)
                        Text("\(course.date) · \(course.period) · \(course.courseID)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            Button {
                Task { await viewModel.submit(token: auth.wrapperToken) }
            } label: {
                Text(viewModel.isSubmitting ? "送出中…" : "確認送出")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .disabled(viewModel.isSubmitting)
            .buttonStyle(PrimaryActionButtonStyle(enabled: !viewModel.isSubmitting))
        }
    }

    private var successStep: some View {
        VStack(spacing: 14) {
            SuccessPulseView()
                .frame(width: 72, height: 72)

            Text("申請送出成功")
                .font(.title3.weight(.bold))

            Text(viewModel.submitMessage ?? "我們已收到你的請假申請，請到請假紀錄查看審核狀態。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("再次申請") {
                viewModel.resetForNewApplication()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.29, green: 0.87, blue: 0.50))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var typeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("假別")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 10) {
                ForEach(viewModel.leaveTypes) { option in
                    let isActive = option.value == viewModel.type
                    Button {
                        Task { await viewModel.updateType(option.value, token: auth.wrapperToken) }
                    } label: {
                        Text(option.label)
                            .font(.subheadline.weight(.semibold))
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(isActive ? .white : leaveTypeColor(for: option.value))
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isActive ? leaveTypeColor(for: option.value) : leaveTypeColor(for: option.value).opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var courseSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("可請假課程")
                .font(.subheadline.weight(.semibold))

            if viewModel.isLoadingCourses {
                ProgressView("載入課程中…")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if viewModel.availableCourses.isEmpty {
                Text("目前沒有可請假的課程")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.availableCourses) { course in
                    let isSelected = viewModel.selectedCoursePayloads.contains(course.id)
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.toggleCourse(course.id)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSelected ? Color(red: 0.22, green: 0.74, blue: 0.98) : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(course.courseName)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Text("\(course.date) · \(course.period) · \(course.courseID)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? Color(red: 0.22, green: 0.74, blue: 0.98) : Color(.separator), lineWidth: 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(isSelected ? Color(red: 0.22, green: 0.74, blue: 0.98).opacity(0.1) : Color(.secondarySystemBackground))
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var leaveReasonInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("請假原因 *")
                .font(.subheadline.weight(.semibold))

            ZStack(alignment: .topLeading) {
                if viewModel.leaveReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("請輸入請假原因")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                }

                TextEditor(text: $viewModel.leaveReason)
                    .focused($isLeaveReasonFocused)
                    .frame(minHeight: 96)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Records Flow

    @ViewBuilder
    private var recordsFlow: some View {
        if let detail = viewModel.detail {
            recordDetailView(detail)
        } else {
            recordsListView
        }
    }

    private var recordsListView: some View {
        VStack(spacing: 10) {
            if viewModel.isLoadingRecords && viewModel.records.isEmpty {
                ProgressView("載入請假紀錄…")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let error = viewModel.recordsError {
                ContentUnavailableView("載入失敗", systemImage: "exclamationmark.triangle", description: Text(error))
                    .frame(maxWidth: .infinity)
            } else if viewModel.records.isEmpty {
                ContentUnavailableView("目前沒有請假紀錄", systemImage: "doc.text")
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(viewModel.records) { record in
                    Button {
                        Task { await viewModel.openDetail(record: record, token: auth.wrapperToken) }
                    } label: {
                        LeaveRecordCard(record: record)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                Task { await viewModel.loadRecords(token: auth.wrapperToken) }
            } label: {
                if viewModel.isLoadingRecords {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                } else {
                    Text("重新整理")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isLoadingRecords)
        }
        .task {
            if viewModel.records.isEmpty {
                await viewModel.loadRecords(token: auth.wrapperToken)
            }
        }
    }

    private func recordDetailView(_ detail: LeaveApplicationViewModel.LeaveRecordDetailState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("← 返回列表") {
                viewModel.closeDetail()
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.medium))

            LeaveStatusBadge(status: detail.status)

            summaryRow(title: "編號", value: detail.recordID)
            summaryRow(title: "假別", value: displayText(detail.typeLabel))
            summaryRow(title: "請假原因", value: displayText(detail.reason))
            summaryRow(title: "審核意見", value: displayText(detail.opinion))

            VStack(alignment: .leading, spacing: 8) {
                Text("請假課程")
                    .font(.subheadline.weight(.semibold))
                if detail.entries.isEmpty {
                    Text("無課程明細")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(detail.entries) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.subject ?? "未命名課程")
                                .font(.subheadline)
                            Text("\(entry.date ?? "-") · \(entry.period ?? "-")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }

            if let error = viewModel.detailError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if leaveStatus(for: detail.status) == .pending {
                Button {
                    Task { await viewModel.cancelCurrentDetail(token: auth.wrapperToken) }
                } label: {
                    Text(viewModel.isCancelling ? "取消中…" : "取消此申請")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .disabled(viewModel.isCancelling)
                .buttonStyle(PrimaryActionButtonStyle(enabled: !viewModel.isCancelling, activeColor: .red))
            }
        }
    }

    // MARK: - Bindings

    private var startDateBinding: Binding<Date> {
        Binding(
            get: { parseDate(viewModel.sdate) ?? Date() },
            set: { newDate in
                Task { await viewModel.updateStartDate(formatDate(newDate), token: auth.wrapperToken) }
            }
        )
    }

    private var endDateBinding: Binding<Date> {
        Binding(
            get: { parseDate(viewModel.edate) ?? parseDate(viewModel.sdate) ?? Date() },
            set: { newDate in
                Task { await viewModel.updateEndDate(formatDate(newDate), token: auth.wrapperToken) }
            }
        )
    }

    private func parseDate(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        return dateFormatter.date(from: string)
    }

    private func formatDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    private func summaryRow(title: String, value: String, color: Color = .primary) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(color)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
        .padding(.vertical, 2)
    }

    private func displayDateRange(start: String?, end: String?) -> String {
        let s = (start ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let e = (end ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return "-" }
        if e.isEmpty || e == s { return s }
        return "\(s) → \(e)"
    }

    private func displayText(_ text: String?) -> String {
        let normalized = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? "-" : normalized
    }

    private func leaveTypeColor(for code: String?) -> Color {
        switch code {
        case "I": return Color(red: 0.22, green: 0.74, blue: 0.98)
        case "2": return Color(red: 0.29, green: 0.87, blue: 0.50)
        case "3": return Color(red: 0.98, green: 0.57, blue: 0.24)
        default: return .secondary
        }
    }
}

private struct PrimaryActionButtonStyle: ButtonStyle {
    let enabled: Bool
    var activeColor: Color = .blue

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(enabled ? Color.white : Color(.darkGray))
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(enabled ? activeColor.opacity(configuration.isPressed ? 0.78 : 1.0) : Color(.systemGray4))
            )
    }
}

private struct LeaveRecordCard: View {
    let record: LeaveApplicationViewModel.LeaveRecordItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                LeaveStatusBadge(status: record.status)
                Spacer()
            }

            Text(displayDate)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Text("編號：\(record.recordID)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var displayDate: String {
        let start = record.sdate ?? String(record.submittedAt?.prefix(10) ?? "")
        let end = record.edate
        if start.isEmpty { return "日期待補" }
        if let end, !end.isEmpty, end != start {
            return "\(start) → \(end)"
        }
        return start
    }

}

private struct LeaveStatusBadge: View {
    let status: String

    var body: some View {
        let style = leaveStatus(for: status)
        Text(style.label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(style.color.opacity(0.18))
            .foregroundStyle(style.color)
            .clipShape(Capsule())
    }
}

private enum LeaveStatusStyle {
    case approved
    case rejected
    case pending
    case cancelled
    case unknown

    var color: Color {
        switch self {
        case .approved:
            return Color(red: 0.29, green: 0.87, blue: 0.50)
        case .rejected:
            return Color(red: 0.92, green: 0.30, blue: 0.24)
        case .pending:
            return Color(red: 0.98, green: 0.80, blue: 0.08)
        case .cancelled:
            return Color(red: 0.39, green: 0.45, blue: 0.54)
        case .unknown:
            return .secondary
        }
    }

    var label: String {
        switch self {
        case .approved: return "已核准"
        case .rejected: return "不通過"
        case .pending: return "審核中"
        case .cancelled: return "已取消"
        case .unknown: return "未知"
        }
    }
}

private func leaveStatus(for rawStatus: String?) -> LeaveStatusStyle {
    let normalized = (rawStatus ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if normalized.contains("cancel") || normalized.contains("取消") {
        return .cancelled
    }
    if normalized.contains("reject")
        || normalized.contains("denied")
        || normalized.contains("駁回")
        || normalized.contains("不通過")
        || normalized.contains("未通過")
    {
        return .rejected
    }
    if normalized.contains("approve") || normalized.contains("核准") || normalized.contains("通過") {
        return .approved
    }
    if normalized.contains("pending") || normalized.contains("審核") || normalized.contains("處理") {
        return .pending
    }
    if normalized.isEmpty {
        return .pending
    }
    return .unknown
}

private struct SuccessPulseView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(red: 0.29, green: 0.87, blue: 0.50).opacity(0.4), lineWidth: 8)
                .scaleEffect(pulse ? 1.1 : 0.85)
                .opacity(pulse ? 0.1 : 0.7)

            Circle()
                .fill(Color(red: 0.29, green: 0.87, blue: 0.50))

            Image(systemName: "checkmark")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        LeaveApplicationView()
            .environment(AuthViewModel())
    }
}
#endif
