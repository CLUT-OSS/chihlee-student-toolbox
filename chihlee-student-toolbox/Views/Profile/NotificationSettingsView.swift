import SwiftUI

struct NotificationSettingsView: View {
    @Environment(ThemeStore.self) private var themeStore
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("scheduleShowNonTimedItems") private var scheduleShowNonTimedItems = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("設定")
                .font(.headline)

            @Bindable var store = themeStore
            Picker("外觀模式", selection: $store.appearance) {
                ForEach(AppAppearance.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Divider()
            Toggle("作業到期提醒", isOn: $notificationsEnabled)
            Divider()
            Toggle("顯示非固定節次", isOn: $scheduleShowNonTimedItems)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
