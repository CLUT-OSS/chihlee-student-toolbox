import Foundation
import SwiftData

#if DEBUG
@MainActor
struct PreviewSampleData {
    static let container: ModelContainer = {
        let schema = Schema([
            Student.self,
            Course.self,
            ClassSession.self,
            NonTimedScheduleEntry.self,
            Assignment.self,
            AttendanceRecord.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])

        let context = container.mainContext
        populateSampleData(context: context)

        return container
    }()

    static func populateSampleData(context: ModelContext) {
        // Student
        let student = Student(
            name: "王小明",
            studentID: "11223344",
            department: "資訊管理系",
            grade: 2
        )
        context.insert(student)

        // Courses
        let courses = [
            Course(name: "程式設計", instructor: "陳教授", colorHex: "#007AFF", credits: 3),
            Course(name: "資料結構", instructor: "林教授", colorHex: "#FF3B30", credits: 3),
            Course(name: "計算機概論", instructor: "張教授", colorHex: "#34C759", credits: 3),
            Course(name: "英文", instructor: "李教授", colorHex: "#FF9500", credits: 2),
        ]
        courses.forEach { context.insert($0) }

        // Class Sessions
        let sessions = [
            ClassSession(course: courses[0], dayOfWeek: .monday, periodCode: "A03", classroom: "E301"),
            ClassSession(course: courses[0], dayOfWeek: .monday, periodCode: "A04", classroom: "E301"),
            ClassSession(course: courses[1], dayOfWeek: .tuesday, periodCode: "A01", classroom: "E405"),
            ClassSession(course: courses[1], dayOfWeek: .tuesday, periodCode: "A02", classroom: "E405"),
            ClassSession(course: courses[2], dayOfWeek: .wednesday, periodCode: "A06", classroom: "D201"),
            ClassSession(course: courses[2], dayOfWeek: .wednesday, periodCode: "A07", classroom: "D201"),
            ClassSession(course: courses[3], dayOfWeek: .thursday, periodCode: "A03", classroom: "B102"),
            ClassSession(course: courses[3], dayOfWeek: .thursday, periodCode: "A04", classroom: "B102"),
        ]
        sessions.forEach { context.insert($0) }

        context.insert(
            NonTimedScheduleEntry(
                dayOfWeekRaw: DayOfWeek.wednesday.rawValue,
                periodLabel: "勞作教育時段",
                name: "商務越南語 培養職場即戰力(磨)",
                classroom: "",
                teacher: "蔡玉鳳",
                syllabusURL: ""
            )
        )

        // Assignments
        let cal = Calendar.current
        let assignments = [
            Assignment(title: "程式設計 HW1", assignmentDescription: "完成第三章練習題", dueDate: cal.date(byAdding: .day, value: 2, to: Date())!, status: .incomplete, course: courses[0]),
            Assignment(title: "資料結構 Lab2", assignmentDescription: "實作鏈結串列", dueDate: cal.date(byAdding: .day, value: 5, to: Date())!, status: .inProgress, course: courses[1]),
            Assignment(title: "計概報告", assignmentDescription: "期中專題報告", dueDate: cal.date(byAdding: .day, value: -1, to: Date())!, status: .submitted, course: courses[2]),
            Assignment(title: "英文作文", assignmentDescription: "Write a 500-word essay", dueDate: cal.date(byAdding: .day, value: 1, to: Date())!, status: .incomplete, course: courses[3]),
        ]
        assignments.forEach { context.insert($0) }

        // Attendance Records
        let attendanceData: [(Course, AttendanceStatus)] = [
            (courses[0], .present),
            (courses[0], .present),
            (courses[0], .late),
            (courses[0], .absent),
            (courses[1], .present),
            (courses[1], .present),
            (courses[1], .sickLeave),
            (courses[2], .present),
            (courses[2], .present),
            (courses[2], .personalLeave),
            (courses[2], .present),
            (courses[3], .present),
            (courses[3], .absent),
            (courses[3], .absent),
        ]
        for (i, (course, status)) in attendanceData.enumerated() {
            let record = AttendanceRecord(
                date: cal.date(byAdding: .day, value: -i * 3, to: Date())!,
                status: status,
                course: course
            )
            context.insert(record)
        }
    }
}
#endif
