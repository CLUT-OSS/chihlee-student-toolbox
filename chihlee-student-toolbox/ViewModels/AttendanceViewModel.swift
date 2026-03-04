import Foundation
import SwiftData
import Observation

@Observable
final class AttendanceViewModel {
    // MARK: - iLife API State

    var allRecords: [IlifeAttendanceRecord] = []
    var isLoadingAPI = false
    var apiError: String?

    struct CourseAbsenceGroup: Identifiable {
        let courseTitle: String
        let records: [IlifeAttendanceRecord]
        var id: String { courseTitle }
        var count: Int { records.count }
    }

    /// All non-出席 records grouped by course title, sorted by count descending
    var absencesByCourse: [CourseAbsenceGroup] {
        let absences = allRecords.filter { $0.status != "出席" }
        let grouped = Dictionary(grouping: absences) { $0.courseTitle ?? "未知課程" }
        return grouped
            .map { CourseAbsenceGroup(courseTitle: $0.key, records: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.count > $1.count }
    }

    var totalAbsences: Int { allRecords.filter { $0.status != "出席" }.count }

    var mostRecentAbsence: IlifeAttendanceRecord? {
        allRecords
            .filter { $0.status != "出席" }
            .sorted { $0.date > $1.date }
            .first
    }

    func loadFromAPI(token: String) async {
        guard !isLoadingAPI else { return }
        isLoadingAPI = true
        apiError = nil
        do {
            allRecords = try await APIService.fetchIlifeAttendance(token: token)
        } catch {
            apiError = error.localizedDescription
        }
        isLoadingAPI = false
    }

    // MARK: - SwiftData (for manual records + schedule context)

    var courses: [Course] = []

    func loadData(context: ModelContext) {
        courses = (try? context.fetch(FetchDescriptor<Course>())) ?? []
    }
}
