import SwiftUI
import SwiftData

struct AddAssignmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var courses: [Course]

    @State private var title = ""
    @State private var description = ""
    @State private var dueDate = Date()
    @State private var selectedCourse: Course?

    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    var onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("作業資訊") {
                    TextField("標題", text: $title)
                    Picker("課程", selection: $selectedCourse) {
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
                    DatePicker("到期日", selection: $dueDate, displayedComponents: .date)
                }

                Section("描述") {
                    TextEditor(text: $description)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("新增作業")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") { save() }
                        .disabled(title.isEmpty)
                }
            }
        }
    }

    private func save() {
        let assignment = Assignment(
            title: title,
            assignmentDescription: description,
            dueDate: dueDate,
            status: .incomplete,
            course: selectedCourse
        )
        modelContext.insert(assignment)

        // Schedule notification
        if notificationsEnabled {
            Task {
                await NotificationManager.shared.scheduleAssignmentReminder(
                    assignmentTitle: title,
                    dueDate: dueDate,
                    identifier: assignment.persistentModelID.hashValue.description
                )
            }
        }

        onSave()
        dismiss()
    }
}
