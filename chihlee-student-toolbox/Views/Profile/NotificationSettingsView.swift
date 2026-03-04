import SwiftUI

struct NotificationSettingsView: View {
    @Environment(ThemeStore.self) private var themeStore
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("scheduleShowNonTimedItems") private var scheduleShowNonTimedItems = true

    var body: some View {
        Section("設定") {
            @Bindable var store = themeStore
            Picker("外觀模式", selection: $store.appearance) {
                ForEach(AppAppearance.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            Toggle("作業到期提醒", isOn: $notificationsEnabled)
            Toggle("顯示非固定節次", isOn: $scheduleShowNonTimedItems)
        }
    }
}
