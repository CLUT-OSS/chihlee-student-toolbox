import SwiftUI

struct AssignmentDetailView: View {
    @Bindable var assignment: Assignment
    @Environment(\.modelContext) private var modelContext
    var onUpdate: () -> Void

    var body: some View {
        Form {
            Section("作業資訊") {
                TextField("標題", text: $assignment.title)

                if let course = assignment.course {
                    HStack {
                        Circle()
                            .fill(ColorHelper.color(from: course.colorHex))
                            .frame(width: 12, height: 12)
                        Text(course.name)
                    }
                }

                DatePicker("到期日", selection: $assignment.dueDate, displayedComponents: .date)
            }

            Section("狀態") {
                Picker("進度", selection: Binding(
                    get: { assignment.status },
                    set: { assignment.statusRaw = $0.rawValue }
                )) {
                    ForEach(AssignmentStatus.allCases, id: \.self) { status in
                        Label(status.label, systemImage: status.iconName).tag(status)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("描述") {
                TextEditor(text: $assignment.assignmentDescription)
                    .frame(minHeight: 100)
            }
        }
        .navigationTitle("作業詳情")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            try? modelContext.save()
            onUpdate()
        }
    }
}
