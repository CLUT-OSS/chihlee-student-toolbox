import SwiftUI
import SwiftData

struct ProfileTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthViewModel.self) private var auth
    @State private var viewModel = ProfileViewModel()
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                if let student = viewModel.student {
                    StudentProfileSection(
                        student: student,
                        email: viewModel.email,
                        isSyncing: viewModel.isSyncing
                    )
                    NotificationSettingsView()
                }

                Section {
                    Button(role: .destructive) {
                        showLogoutConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("登出", systemImage: "rectangle.portrait.and.arrow.right")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("個人資料")
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
}

#if DEBUG
#Preview {
    ProfileTabView()
        .modelContainer(PreviewSampleData.container)
}
#endif
