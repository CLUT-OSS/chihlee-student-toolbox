import SwiftUI
import SwiftData

struct RecordAttendanceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var courses: [Course]

    @State private var selectedCourse: Course?
    @State private var date = Date()
    @State private var status: AttendanceStatus = .present

    var onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("課程") {
                    Picker("選擇課程", selection: $selectedCourse) {
                        Text("請選擇").tag(nil as Course?)
                        ForEach(courses, id: \.persistentModelID) { course in
                            HStack {
                                Circle()
                                    .fill(ColorHelper.color(from: course.colorHex))
                                    .frame(width: 10, height: 10)
                                Text(course.name)
                            }
                            .tag(course as Course?)
                        }
                    }
                }

                Section("日期") {
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                }

                Section("出缺勤狀態") {
                    ForEach(AttendanceStatus.allCases, id: \.self) { s in
                        HStack {
                            Circle()
                                .fill(s.color)
                                .frame(width: 10, height: 10)
                            Text(s.label)
                            Spacer()
                            if status == s {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            status = s
                        }
                    }
                }
            }
            .navigationTitle("記錄出缺勤")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") { save() }
                        .disabled(selectedCourse == nil)
                }
            }
        }
    }

    private func save() {
        let record = AttendanceRecord(date: date, status: status, course: selectedCourse)
        modelContext.insert(record)
        onSave()
        dismiss()
    }
}
