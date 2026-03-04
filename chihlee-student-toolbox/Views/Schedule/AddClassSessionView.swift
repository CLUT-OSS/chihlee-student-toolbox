import SwiftUI
import SwiftData

struct AddClassSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var courses: [Course]

    @State private var selectedCourse: Course?
    @State private var selectedDay: DayOfWeek = .monday
    @State private var selectedPeriod: String = "A01"
    @State private var classroom: String = ""

    // For adding a new course inline
    @State private var showNewCourse = false
    @State private var newCourseName = ""
    @State private var newInstructor = ""
    @State private var newColorHex = "#007AFF"
    @State private var newCredits = 3

    var onSave: () -> Void

    private var availablePeriods: [PeriodDefinition] {
        ScheduleViewModel.periods(for: selectedDay)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("課程") {
                    if courses.isEmpty && !showNewCourse {
                        Text("尚無課程，請先新增")
                            .foregroundStyle(.secondary)
                    }
                    Picker("選擇課程", selection: $selectedCourse) {
                        Text("請選擇").tag(nil as Course?)
                        ForEach(courses, id: \.persistentModelID) { course in
                            Text(course.name).tag(course as Course?)
                        }
                    }
                    Button("新增課程") {
                        showNewCourse.toggle()
                    }

                    if showNewCourse {
                        TextField("課程名稱", text: $newCourseName)
                        TextField("授課教師", text: $newInstructor)
                        Stepper("學分: \(newCredits)", value: $newCredits, in: 1...6)
                        Picker("顏色", selection: $newColorHex) {
                            ForEach(ColorHelper.courseColors, id: \.hex) { c in
                                HStack {
                                    Circle().fill(ColorHelper.color(from: c.hex)).frame(width: 16, height: 16)
                                    Text(c.name)
                                }
                                .tag(c.hex)
                            }
                        }
                        Button("建立課程") {
                            let course = Course(name: newCourseName, instructor: newInstructor, colorHex: newColorHex, credits: newCredits)
                            modelContext.insert(course)
                            selectedCourse = course
                            showNewCourse = false
                            newCourseName = ""
                            newInstructor = ""
                        }
                        .disabled(newCourseName.isEmpty)
                    }
                }

                Section("時間地點") {
                    Picker("星期", selection: $selectedDay) {
                        ForEach(DayOfWeek.allCases, id: \.rawValue) { day in
                            Text(day.fullName).tag(day)
                        }
                    }
                    Picker("節次", selection: $selectedPeriod) {
                        ForEach(availablePeriods) { period in
                            Text("\(period.code)  \(period.timeRange)").tag(period.code)
                        }
                    }
                    TextField("教室", text: $classroom)
                }
            }
            .navigationTitle("新增課程時段")
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
            .onChange(of: selectedDay) { _, _ in
                // Reset period if current selection is not available for new day
                if !availablePeriods.contains(where: { $0.code == selectedPeriod }) {
                    selectedPeriod = availablePeriods.first?.code ?? "A01"
                }
            }
        }
    }

    private func save() {
        let session = ClassSession(
            course: selectedCourse,
            dayOfWeek: selectedDay,
            periodCode: selectedPeriod,
            classroom: classroom
        )
        selectedCourse?.sessions.append(session)
        modelContext.insert(session)
        onSave()
        dismiss()
    }
}
