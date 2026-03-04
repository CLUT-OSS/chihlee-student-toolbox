import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class ProfileViewModel {
    var student: Student?
    var email: String?
    var isSyncing = false
    var syncError: String?

    func loadOrCreateStudent(context: ModelContext) {
        let students = (try? context.fetch(FetchDescriptor<Student>())) ?? []
        if let existing = students.first {
            student = existing
        } else {
            let newStudent = Student()
            context.insert(newStudent)
            student = newStudent
            save(context: context)
        }
    }

    func fetchAndSync(token: String?, context: ModelContext) async {
        guard !isSyncing else { return }
        guard let token, !token.isEmpty else { return }
        isSyncing = true
        syncError = nil
        do {
            let profile = try await APIService.fetchDlcProfile(token: token)
            if let student {
                if let name = profile.name, !name.isEmpty { student.name = name }
                if let account = profile.account, !account.isEmpty { student.studentID = account }
            }
            email = profile.email
            save(context: context)
        } catch {
            syncError = error.localizedDescription
        }
        isSyncing = false
    }

    func save(context: ModelContext) {
        try? context.save()
    }
}
