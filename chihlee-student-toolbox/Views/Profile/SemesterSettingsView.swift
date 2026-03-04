import SwiftUI

struct SemesterSettingsView: View {
    @Bindable var student: Student

    var body: some View {
        Section("學期設定") {
            DatePicker("學期開始", selection: $student.semesterStart, displayedComponents: .date)
            DatePicker("學期結束", selection: $student.semesterEnd, displayedComponents: .date)
        }
    }
}
