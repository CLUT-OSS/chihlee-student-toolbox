import Foundation
import UserNotifications

final class NotificationManager: @unchecked Sendable {
    static let shared = NotificationManager()
    private init() {}

    func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    func scheduleAssignmentReminder(assignmentTitle: String, dueDate: Date, identifier: String) async {
        let content = UNMutableNotificationContent()
        content.title = "作業提醒"
        content.body = "「\(assignmentTitle)」明天到期！"
        content.sound = .default

        // Remind one day before due date
        guard let reminderDate = Calendar.current.date(byAdding: .day, value: -1, to: dueDate) else { return }
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try? await UNUserNotificationCenter.current().add(request)
    }

    func cancelNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
