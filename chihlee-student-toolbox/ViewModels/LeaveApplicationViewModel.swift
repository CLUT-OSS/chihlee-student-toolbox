import Foundation
import Observation

@MainActor
@Observable
final class LeaveApplicationViewModel {
    enum SubView {
        case apply
        case records
    }

    enum ApplyStep: Int {
        case form = 1
        case confirm = 2
        case success = 3
    }

    struct LeaveCourseOption: Identifiable, Hashable {
        let id: String // unique selection key: YYYY-MM-DD,PERIOD,COURSE_ID
        let date: String
        let period: String
        let courseID: String
        let courseName: String
        let roomNo: String?
    }

    struct LeaveRecordItem: Identifiable {
        let recordID: String
        var status: String
        var typeCode: String?
        var typeLabel: String?
        var sdate: String?
        var edate: String?
        var courseCount: Int?
        var submittedAt: String?

        var id: String { recordID }

        init(record: IlifeLeaveRecord) {
            recordID = record.recordID
            status = record.status ?? "pending"
            typeCode = record.type
            typeLabel = record.leaveType
            sdate = record.sdate
            edate = record.edate
            courseCount = record.courseCount
            submittedAt = record.submittedAt
        }
    }

    struct LeaveRecordDetailState {
        let recordID: String
        var status: String
        var typeCode: String?
        var typeLabel: String?
        var reason: String?
        var opinion: String?
        var sdate: String?
        var edate: String?
        var entries: [IlifeLeaveRecordDetailEntry]

        init(record: LeaveRecordItem, detail: IlifeLeaveRecordDetail) {
            recordID = record.recordID
            status = detail.status ?? record.status
            typeCode = detail.type ?? record.typeCode
            typeLabel = detail.leaveType ?? record.typeLabel
            reason = detail.reason
            opinion = detail.opinion
            sdate = detail.sdate ?? record.sdate
            edate = detail.edate ?? record.edate
            entries = detail.entries
        }
    }

    // MARK: - Apply

    var sub: SubView = .apply
    var step: ApplyStep = .form

    var sdate = ""
    var edate = ""
    var type = "3"
    var leaveReason = ""

    var leaveTypes: [IlifeLeaveTypeOption] = [
        IlifeLeaveTypeOption(value: "I", label: "身心調適假", caption: nil),
        IlifeLeaveTypeOption(value: "2", label: "病假", caption: nil),
        IlifeLeaveTypeOption(value: "3", label: "事假", caption: nil),
    ]

    var availableCourses: [LeaveCourseOption] = []
    var selectedCoursePayloads: Set<String> = []

    var isLoadingCourses = false
    var isSubmitting = false
    var applyError: String?
    var submitMessage: String?

    // MARK: - Records

    var records: [LeaveRecordItem] = []
    var isLoadingRecords = false
    var recordsError: String?

    var detail: LeaveRecordDetailState?
    var isLoadingDetail = false
    var detailError: String?
    var isCancelling = false

    var selectedCourses: [LeaveCourseOption] {
        availableCourses.filter { selectedCoursePayloads.contains($0.id) }
    }

    var selectedTypeOption: IlifeLeaveTypeOption {
        leaveTypes.first(where: { $0.value == type })
            ?? IlifeLeaveTypeOption(value: type, label: type, caption: nil)
    }

    var canProceedToConfirm: Bool {
        !sdate.isEmpty && !selectedCoursePayloads.isEmpty && !leaveReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func switchSub(_ sub: SubView, token: String?) async {
        self.sub = sub
        if sub == .records, records.isEmpty {
            await loadRecords(token: token)
        }
    }

    func updateStartDate(_ value: String, token: String?) async {
        sdate = value
        if edate.isEmpty || edate < value {
            edate = value
        }
        selectedCoursePayloads.removeAll()
        await loadCoursesIfNeeded(token: token)
    }

    func updateEndDate(_ value: String, token: String?) async {
        if !sdate.isEmpty, value < sdate {
            edate = sdate
        } else {
            edate = value
        }
        selectedCoursePayloads.removeAll()
        await loadCoursesIfNeeded(token: token)
    }

    func updateType(_ value: String, token: String?) async {
        type = value
        selectedCoursePayloads.removeAll()
        await loadCoursesIfNeeded(token: token)
    }

    func toggleCourse(_ payload: String) {
        if selectedCoursePayloads.contains(payload) {
            selectedCoursePayloads.remove(payload)
        } else {
            selectedCoursePayloads.insert(payload)
        }
    }

    func goToConfirm() {
        guard canProceedToConfirm else { return }
        step = .confirm
    }

    func backToForm() {
        step = .form
    }

    func submit(token: String?) async {
        guard canProceedToConfirm else { return }
        guard let token, !token.isEmpty else {
            applyError = "尚未登入，無法送出請假。"
            return
        }
        let reason = leaveReason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reason.isEmpty else {
            applyError = "請輸入請假原因。"
            return
        }

        isSubmitting = true
        applyError = nil
        defer { isSubmitting = false }

        do {
            let result = try await APIService.submitIlifeLeave(
                token: token,
                type: type,
                sdate: sdate,
                edate: edate.isEmpty ? sdate : edate,
                reason: reason,
                leaves: selectedCourses
                    .sorted(by: { ($0.date, $0.period, $0.courseID) < ($1.date, $1.period, $1.courseID) })
                    .map { course in
                        APIService.IlifeLeaveSubmitCourse(
                            courseID: course.courseID,
                            date: course.date,
                            period: course.period
                        )
                    }
            )
            if result.success {
                submitMessage = result.message
                step = .success
                await loadRecords(token: token)
            } else {
                applyError = result.message
            }
        } catch {
            applyError = error.localizedDescription
        }
    }

    func resetForNewApplication() {
        step = .form
        selectedCoursePayloads.removeAll()
        sdate = ""
        edate = ""
        type = "3"
        leaveReason = ""
        applyError = nil
        submitMessage = nil
        availableCourses = []
    }

    func loadCoursesIfNeeded(token: String?) async {
        guard !sdate.isEmpty else {
            availableCourses = []
            return
        }
        guard let token, !token.isEmpty else {
            availableCourses = []
            applyError = "尚未登入，無法讀取可請假課程。"
            return
        }

        isLoadingCourses = true
        applyError = nil
        defer { isLoadingCourses = false }

        do {
            let payload = try await APIService.fetchIlifeLeave(
                token: token,
                sdate: sdate,
                edate: edate.isEmpty ? nil : edate,
                type: type
            )
            leaveTypes = payload.leaveTypes
            availableCourses = flattenCourseOptions(from: payload, fallbackDate: sdate)
            selectedCoursePayloads = selectedCoursePayloads.intersection(Set(availableCourses.map(\.id)))
        } catch {
            applyError = error.localizedDescription
            availableCourses = []
        }
    }

    func loadRecords(token: String?) async {
        guard let token, !token.isEmpty else {
            records = []
            recordsError = "尚未登入，無法讀取請假紀錄。"
            return
        }

        isLoadingRecords = true
        recordsError = nil
        defer { isLoadingRecords = false }

        do {
            records = try await APIService.fetchIlifeLeaveRecords(token: token)
                .map(LeaveRecordItem.init(record:))
        } catch {
            recordsError = error.localizedDescription
            records = []
        }
    }

    func openDetail(record: LeaveRecordItem, token: String?) async {
        guard let token, !token.isEmpty else {
            detailError = "尚未登入，無法讀取明細。"
            return
        }

        isLoadingDetail = true
        detailError = nil
        defer { isLoadingDetail = false }

        do {
            let payload = try await APIService.fetchIlifeLeaveRecordDetail(token: token, recordID: record.recordID)
            detail = LeaveRecordDetailState(record: record, detail: payload)

            if let index = records.firstIndex(where: { $0.recordID == record.recordID }) {
                records[index].status = detail?.status ?? records[index].status
                records[index].typeCode = detail?.typeCode ?? records[index].typeCode
                records[index].typeLabel = detail?.typeLabel ?? records[index].typeLabel
                records[index].sdate = detail?.sdate ?? records[index].sdate
                records[index].edate = detail?.edate ?? records[index].edate
                records[index].courseCount = detail?.entries.count ?? records[index].courseCount
            }
        } catch {
            detailError = error.localizedDescription
        }
    }

    func closeDetail() {
        detail = nil
        detailError = nil
    }

    func cancelCurrentDetail(token: String?) async {
        guard let token, !token.isEmpty else {
            detailError = "尚未登入，無法取消申請。"
            return
        }
        guard let detail else { return }

        isCancelling = true
        detailError = nil
        defer { isCancelling = false }

        do {
            let result = try await APIService.cancelIlifeLeave(token: token, recordID: detail.recordID)
            guard result.success else {
                detailError = result.message
                return
            }

            if let index = records.firstIndex(where: { $0.recordID == detail.recordID }) {
                records[index].status = "cancelled"
            }
            self.detail?.status = "cancelled"
        } catch {
            detailError = error.localizedDescription
        }
    }

    // MARK: - Private

    private func flattenCourseOptions(from payload: IlifeLeaveData, fallbackDate: String) -> [LeaveCourseOption] {
        let options: [LeaveCourseOption] = payload.courses?.days.flatMap { day in
            day.periods.compactMap { period in
                let courseID = period.subjectID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !courseID.isEmpty else { return nil }

                let normalizedDate = normalizedDateString(from: day.displayDate, fallback: fallbackDate)
                let selectionKey = "\(normalizedDate),\(period.period),\(courseID)"
                return LeaveCourseOption(
                    id: selectionKey,
                    date: normalizedDate,
                    period: period.period,
                    courseID: courseID,
                    courseName: period.courseName,
                    roomNo: period.roomNo
                )
            }
        } ?? []

        var unique = Set<String>()
        return options.filter { unique.insert($0.id).inserted }
    }

    private func normalizedDateString(from displayDate: String, fallback: String) -> String {
        if let match = displayDate.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression) {
            return String(displayDate[match])
        }
        if let match = displayDate.range(of: #"\d{4}/\d{1,2}/\d{1,2}"#, options: .regularExpression) {
            return String(displayDate[match]).replacingOccurrences(of: "/", with: "-")
        }
        return fallback
    }
}
