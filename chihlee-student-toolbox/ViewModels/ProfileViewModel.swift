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
    var digitalPass: IlifeDigitalPass?
    var isLoadingDigitalPass = false
    var digitalPassError: String?
    var photoData: Data?
    var qrData: Data?
    var isLoadingPhoto = false
    var isLoadingQR = false
    var photoError: String?
    var qrError: String?

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
        digitalPassError = nil
        isLoadingDigitalPass = true

        async let profileResultTask = fetchDlcProfileResult(token: token)
        async let digitalPassResultTask = fetchDigitalPassResult(token: token)
        let profileResult = await profileResultTask
        let digitalPassResult = await digitalPassResultTask
        isLoadingDigitalPass = false

        switch profileResult {
        case .success(let profile):
            if let student {
                if let name = profile.name, !name.isEmpty {
                    student.name = name
                }
                if let account = profile.account, !account.isEmpty {
                    student.studentID = account
                }
            }
            email = profile.email
            save(context: context)
        case .failure(let error):
            syncError = error.localizedDescription
        }

        switch digitalPassResult {
        case .success(let payload):
            digitalPass = payload
            if let student {
                if !payload.name.isEmpty {
                    student.name = payload.name
                }
                if !payload.studentID.isEmpty {
                    student.studentID = payload.studentID
                }
                if !payload.department.isEmpty {
                    student.department = payload.department
                }
                save(context: context)
            }
            await fetchDigitalPassAssets(token: token, studentID: payload.studentID)
        case .failure(let error):
            digitalPassError = error.localizedDescription
            digitalPass = nil
            photoData = nil
            qrData = nil
        }
        isSyncing = false
    }

    func save(context: ModelContext) {
        try? context.save()
    }

    private func fetchDlcProfileResult(token: String) async -> Result<DlcProfile, Error> {
        do {
            return .success(try await APIService.fetchDlcProfile(token: token))
        } catch {
            return .failure(error)
        }
    }

    private func fetchDigitalPassResult(token: String) async -> Result<IlifeDigitalPass, Error> {
        do {
            return .success(try await APIService.fetchIlifeDigitalPass(token: token))
        } catch {
            return .failure(error)
        }
    }

    private func fetchDigitalPassAssets(token: String, studentID: String) async {
        photoError = nil
        qrError = nil
        isLoadingPhoto = true
        isLoadingQR = !studentID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        async let photoResultTask = fetchDigitalPassPhotoResult(token: token)
        async let qrResultTask = fetchDigitalPassQRResult(token: token, studentID: studentID)
        let photoResult = await photoResultTask
        let qrResult = await qrResultTask

        isLoadingPhoto = false
        isLoadingQR = false

        switch photoResult {
        case .success(let data):
            photoData = data
        case .failure(let error):
            photoData = nil
            photoError = error.localizedDescription
        }

        switch qrResult {
        case .success(let data):
            qrData = data
        case .failure(let error):
            qrData = nil
            qrError = error.localizedDescription
        }
    }

    private func fetchDigitalPassPhotoResult(token: String) async -> Result<Data, Error> {
        do {
            return .success(try await APIService.fetchIlifeDigitalPassPhoto(token: token))
        } catch {
            return .failure(error)
        }
    }

    private func fetchDigitalPassQRResult(token: String, studentID: String) async -> Result<Data, Error> {
        let normalizedStudentID = studentID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedStudentID.isEmpty else {
            return .failure(AuthError.serverError("缺少學生證 QR 內容"))
        }
        do {
            return .success(try await APIService.fetchIlifeDigitalPassQR(
                token: token,
                q: normalizedStudentID,
                format: "jpg"
            ))
        } catch {
            return .failure(error)
        }
    }
}
