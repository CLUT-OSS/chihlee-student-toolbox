import SwiftUI
import SwiftData
import UIKit

struct ProfileTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthViewModel.self) private var auth
    @State private var viewModel = ProfileViewModel()
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    schoolHeaderCard
                    digitalPassMainCard
                    detailsCard
                    currentTimeCard
                    statusCards
                    NotificationSettingsView()
                    logoutCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("個人")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                viewModel.loadOrCreateStudent(context: modelContext)
            }
            .task(id: auth.wrapperToken) {
                await viewModel.fetchAndSync(token: auth.wrapperToken, context: modelContext)
            }
            .confirmationDialog("確定要登出嗎？", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
                Button("登出", role: .destructive) {
                    Task { await auth.logout() }
                }
            }
        }
    }

    private var schoolHeaderCard: some View {
        card {
            HStack(spacing: 12) {
                Text("🎓")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text("致理科技大學")
                        .font(.headline.weight(.semibold))
                    Text("Chihlee University of Technology")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private var digitalPassMainCard: some View {
        card {
            HStack(alignment: .top, spacing: 12) {
                photoPanel
                VStack(alignment: .leading, spacing: 10) {
                    Text(displayName)
                        .font(.title3.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .allowsTightening(true)
                    Text(displayStudentID)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .allowsTightening(true)
                    enrollmentBadge
                }
                Spacer(minLength: 0)
                qrPanel
            }
        }
    }

    private var detailsCard: some View {
        card {
            VStack(spacing: 0) {
                infoRow(title: "系所", value: displayDepartment)
                Divider().padding(.vertical, 12)
                infoRow(title: "班級", value: displayClass)
                Divider().padding(.vertical, 12)
                infoRow(title: "學號", value: displayStudentID)
                Divider().padding(.vertical, 12)
                infoRow(title: "姓名", value: displayName)
                Divider().padding(.vertical, 12)
                infoRow(title: "Email", value: emailDisplayValue, truncationMode: .middle)
            }
        }
    }

    private var currentTimeCard: some View {
        card {
            VStack(spacing: 10) {
                Text("目前時間")
                    .font(.headline)
                    .foregroundStyle(.white)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(Self.timeFormatter.string(from: context.date))
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }

    private var statusCards: some View {
        HStack(alignment: .top, spacing: 12) {
            card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("註冊狀態")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(displayRegistrationStatus)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(displayRegistrationStatusColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("費用狀態")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(displayActivityFeeStatus)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(displayActivityFeeStatusColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var logoutCard: some View {
        card {
            Button(role: .destructive) {
                showLogoutConfirm = true
            } label: {
                HStack {
                    Spacer()
                    Label("登出", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.headline)
                    Spacer()
                }
            }
        }
    }

    private var photoPanel: some View {
        ZStack {
            if let image = photoImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(4)
            } else if isPhotoLoading {
                ProgressView()
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.8))
                    .frame(width: 82, height: 82)
                    .background(
                        Circle()
                            .fill(Color.blue)
                    )
            }
        }
        .background(Color.clear)
        .frame(width: 92, height: 120)
    }

    private var qrPanel: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white)
                if let image = qrImage {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .padding(8)
                } else if isQRLoading {
                    ProgressView()
                } else {
                    Image(systemName: "qrcode")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 96, height: 96)

            Text("QR Code")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func infoRow(
        title: String,
        value: String,
        truncationMode: Text.TruncationMode = .tail
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.headline.weight(.semibold))
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
                .truncationMode(truncationMode)
                .layoutPriority(1)
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content)
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

    private var displayName: String {
        displayText(
            primary: viewModel.digitalPass?.name,
            fallback: viewModel.student?.name,
            loading: viewModel.isLoadingDigitalPass
        )
    }

    private var displayStudentID: String {
        displayText(
            primary: viewModel.digitalPass?.studentID,
            fallback: viewModel.student?.studentID,
            loading: viewModel.isLoadingDigitalPass
        )
    }

    private var displayDepartment: String {
        displayText(
            primary: viewModel.digitalPass?.department,
            fallback: viewModel.student?.department,
            loading: viewModel.isLoadingDigitalPass
        )
    }

    private var displayClass: String {
        displayText(primary: viewModel.digitalPass?.studentClass, loading: viewModel.isLoadingDigitalPass)
    }

    private var displayRegistrationStatus: String {
        displayText(primary: viewModel.digitalPass?.registrationStatus, loading: viewModel.isLoadingDigitalPass)
    }

    private var displayActivityFeeStatus: String {
        displayText(primary: viewModel.digitalPass?.activityFeeStatus, loading: viewModel.isLoadingDigitalPass)
    }

    private var emailDisplayValue: String {
        if let email = viewModel.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            return email
        }
        return viewModel.isSyncing ? "載入中..." : "—"
    }

    private var enrollmentBadge: some View {
        let text = displayText(primary: viewModel.digitalPass?.enrollmentStatus, loading: viewModel.isLoadingDigitalPass)
        let isActive = text.contains("在學")

        return Text("● \(text)")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(isActive ? .green : .orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background((isActive ? Color.green : Color.orange).opacity(0.15))
            .clipShape(Capsule())
    }

    private var displayRegistrationStatusColor: Color {
        let value = viewModel.digitalPass?.registrationStatus ?? ""
        if value.contains("已完成") {
            return .green
        }
        if value.isEmpty {
            return .secondary
        }
        return .orange
    }

    private var displayActivityFeeStatusColor: Color {
        let value = viewModel.digitalPass?.activityFeeStatus ?? ""
        if value.contains("未繳") {
            return .red
        }
        if value.isEmpty {
            return .secondary
        }
        return .green
    }

    private var photoImage: UIImage? {
        guard let data = viewModel.photoData else { return nil }
        return UIImage(data: data)
    }

    private var qrImage: UIImage? {
        guard let data = viewModel.qrData else { return nil }
        return UIImage(data: data)
    }

    private var isPhotoLoading: Bool {
        viewModel.isLoadingPhoto || (viewModel.isSyncing && viewModel.photoData == nil)
    }

    private var isQRLoading: Bool {
        viewModel.isLoadingQR || (viewModel.isSyncing && viewModel.qrData == nil)
    }

    private func displayText(primary: String?, fallback: String? = nil, loading: Bool) -> String {
        let normalizedPrimary = primary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !normalizedPrimary.isEmpty {
            return normalizedPrimary
        }

        let normalizedFallback = fallback?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !normalizedFallback.isEmpty {
            return normalizedFallback
        }

        return loading ? "載入中..." : "—"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

#if DEBUG
#Preview {
    ProfileTabView()
        .modelContainer(PreviewSampleData.container)
        .environment(AuthViewModel())
        .environment(ThemeStore())
}
#endif
