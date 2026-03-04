import SwiftUI

struct StudentProfileSection: View {
    let student: Student
    var email: String?
    var isSyncing: Bool = false

    var body: some View {
        Section("基本資料") {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    if student.name.isEmpty {
                        Text("尚未設定姓名")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(student.name)
                            .font(.title2.bold())
                    }
                    if !student.studentID.isEmpty {
                        Text(student.studentID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)

            LabeledContent("姓名", value: student.name.isEmpty ? "—" : student.name)
            LabeledContent("學號", value: student.studentID.isEmpty ? "—" : student.studentID)
            LabeledContent("Email", value: emailDisplayValue)
        }
    }

    private var emailDisplayValue: String {
        if let email, !email.isEmpty { return email }
        return isSyncing ? "載入中..." : "—"
    }
}
