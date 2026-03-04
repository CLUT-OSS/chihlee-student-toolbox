import SwiftUI

struct NotificationSettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("scheduleShowNonTimedItems") private var scheduleShowNonTimedItems = true

    var body: some View {
        Section("設定") {
            Toggle("作業到期提醒", isOn: $notificationsEnabled)
            Toggle("顯示非固定節次", isOn: $scheduleShowNonTimedItems)
        }
    }
}
