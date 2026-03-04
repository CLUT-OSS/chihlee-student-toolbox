import SwiftUI

struct LoginView: View {
    @Environment(AuthViewModel.self) private var auth

    @State private var muid = ""
    @State private var mpassword = ""
    @FocusState private var focusedField: Field?

    enum Field { case muid, mpassword }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)

                    Text("致理科技大學")
                        .font(.title2.bold())

                    Text("學生百寶箱")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 64)
                .padding(.bottom, 48)

                // Login form
                VStack(spacing: 16) {
                    // muid
                    VStack(alignment: .leading, spacing: 6) {
                        Text("學號")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        HStack {
                            Image(systemName: "person")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            TextField("請輸入學號", text: $muid)
                                .textContentType(.username)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .focused($focusedField, equals: .muid)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .mpassword }
                        }
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(focusedField == .muid ? Color.blue : Color.clear, lineWidth: 1.5)
                        )
                    }

                    // mpassword
                    VStack(alignment: .leading, spacing: 6) {
                        Text("密碼")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        HStack {
                            Image(systemName: "lock")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            SecureField("請輸入密碼", text: $mpassword)
                                .textContentType(.password)
                                .focused($focusedField, equals: .mpassword)
                                .submitLabel(.go)
                                .onSubmit { Task { await doLogin() } }
                        }
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(focusedField == .mpassword ? Color.blue : Color.clear, lineWidth: 1.5)
                        )
                    }

                    // Error message
                    if let error = auth.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(error)
                                .font(.subheadline)
                        }
                        .foregroundStyle(.red)
                        .padding(.vertical, 4)
                    }

                    // Login button
                    Button {
                        Task { await doLogin() }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(canLogin ? Color.blue : Color.blue.opacity(0.4))
                            if auth.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("登入")
                                    .font(.body.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(height: 52)
                    }
                    .disabled(!canLogin || auth.isLoading)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 28)

                Spacer(minLength: 48)

                // Footer note
                Text("使用學校 CIP 帳號密碼登入")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 32)
            }
        }
        .onAppear { focusedField = .muid }
    }

    private var canLogin: Bool {
        !muid.trimmingCharacters(in: .whitespaces).isEmpty &&
        !mpassword.isEmpty
    }

    private func doLogin() async {
        focusedField = nil
        await auth.login(
            muid: muid.trimmingCharacters(in: .whitespaces),
            mpassword: mpassword
        )
    }
}

#Preview {
    LoginView()
        .environment(AuthViewModel())
}
