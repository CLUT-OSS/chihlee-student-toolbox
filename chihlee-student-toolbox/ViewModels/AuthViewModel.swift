import Foundation
import Observation

struct AuthDebugMetrics {
    var userLoginRequests = 0
    var tokenLoginAttempts = 0
    var tokenLoginSuccesses = 0
    var tokenLoginFailures = 0
    var dlcProfileChecks = 0
    var dlcProfileInvalidCount = 0
    var sessionValidationRuns = 0
    var sessionCheckCalls = 0
    var sessionCheckSuccesses = 0
    var sessionCheckFailures = 0
    var refreshAttempts = 0
    var refreshSuccesses = 0
    var refreshFailures = 0
    var lastSessionValidationAt: Date?
    var lastLoginAttemptAt: Date?
    var lastSuccessfulLoginAt: Date?
    var lastRefreshAt: Date?
    var lastRefreshReason: String?
    var lastErrorMessage: String?
}

@MainActor
@Observable
final class AuthViewModel {
    var isAuthenticated = false
    var isLoading = false
    var errorMessage: String?
    var dlcConnected = false
    var debugMetrics = AuthDebugMetrics()
    private var isSessionValidationInFlight = false

    private let credentialStore = CredentialStore.shared
    private static let legacyWrapperTokenKey = "wrapperToken"
    private static let sessionRefreshInterval: TimeInterval = 5 * 60
    private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private(set) var wrapperToken: String? {
        get { credentialStore.loadWrapperToken() }
        set {
            guard let token = newValue?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
                credentialStore.clearWrapperToken()
                return
            }
            credentialStore.saveWrapperToken(token)
        }
    }

    init() {
        migrateLegacyWrapperTokenIfNeeded()
        // Restore auth state from persisted token
        isAuthenticated = wrapperToken != nil && !(wrapperToken?.isEmpty ?? true)
    }

    // MARK: - Actions

    func login(muid: String, mpassword: String) async {
        isLoading = true
        errorMessage = nil
        debugMetrics.userLoginRequests += 1
        do {
            let result = try await loginEnsuringValidDlcAccount(
                muid: muid,
                mpassword: mpassword
            )
            credentialStore.save(muid: muid, mpassword: mpassword)
            applyLoggedInState(token: result.wrapperToken, dlcConnected: result.dlcConnected)
        } catch {
            errorMessage = error.localizedDescription
            debugMetrics.lastErrorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func logout(includeLiveActivityUnregister: Bool = true) async {
        if let token = wrapperToken {
            if includeLiveActivityUnregister,
               let idfv = Self.normalized(AuthService.identifierForVendor) {
                _ = try? await APIService.unregisterLiveActivityDevice(
                    token: token,
                    idfv: idfv,
                    bundleID: Self.normalized(Bundle.main.bundleIdentifier)
                )
            }
            try? await AuthService.logout(token: token)
        }
        clearAuthState(clearCredentials: true)
    }

    /// Validate and refresh persisted session on app launch or app resume.
    func validateSession() async {
        guard !isSessionValidationInFlight else { return }
        isSessionValidationInFlight = true
        defer { isSessionValidationInFlight = false }
        debugMetrics.sessionValidationRuns += 1
        debugMetrics.lastSessionValidationAt = Date()

        guard let token = wrapperToken, !token.isEmpty else {
            let refreshed = await refreshTokenFromStoredCredentials(reason: "no_local_token")
            if !refreshed {
                clearAuthState(clearCredentials: false)
            }
            return
        }

        do {
            debugMetrics.sessionCheckCalls += 1
            let session = try await AuthService.checkSession(token: token)
            debugMetrics.sessionCheckSuccesses += 1
            if let currentWrapperToken = session.wrapperToken?.trimmingCharacters(in: .whitespacesAndNewlines),
               !currentWrapperToken.isEmpty,
               currentWrapperToken != token {
                wrapperToken = currentWrapperToken
            }
            dlcConnected = session.dlcConnected
            isAuthenticated = true

            if shouldRefreshToken(using: session) {
                _ = await refreshTokenFromStoredCredentials(reason: "session_stale_or_missing_token")
            }
        } catch let authError as AuthError {
            debugMetrics.sessionCheckFailures += 1
            debugMetrics.lastErrorMessage = authError.localizedDescription
            switch authError {
            case .invalidCredentials:
                let refreshed = await refreshTokenFromStoredCredentials(reason: "session_invalid_credentials")
                if !refreshed {
                    clearAuthState(clearCredentials: true)
                }
            case .tooManyRequests, .serverError, .networkError, .decodingError:
                isAuthenticated = wrapperToken != nil && !(wrapperToken?.isEmpty ?? true)
            }
        } catch {
            debugMetrics.sessionCheckFailures += 1
            debugMetrics.lastErrorMessage = error.localizedDescription
            isAuthenticated = wrapperToken != nil && !(wrapperToken?.isEmpty ?? true)
        }
    }

    private func applyLoggedInState(token: String, dlcConnected: Bool) {
        wrapperToken = token
        self.dlcConnected = dlcConnected
        isAuthenticated = true
        errorMessage = nil
    }

    private func clearAuthState(clearCredentials: Bool) {
        wrapperToken = nil
        isAuthenticated = false
        dlcConnected = false
        if clearCredentials {
            credentialStore.clear()
        }
    }

    private func shouldRefreshToken(using session: SessionStatusData) -> Bool {
        let isTokenMissing = (session.wrapperToken?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let isSessionExpiringSoon = isExpiringWithinRefreshInterval(session.expiresAt)
        return isTokenMissing || isSessionExpiringSoon
    }

    private func isExpiringWithinRefreshInterval(_ expiresAt: String?) -> Bool {
        guard let expiresAt else { return true }
        guard let expiryDate = Self.parseServerDate(expiresAt) else { return true }
        return expiryDate.timeIntervalSinceNow <= Self.sessionRefreshInterval
    }

    private static func parseServerDate(_ value: String) -> Date? {
        if let parsed = iso8601WithFractionalSeconds.date(from: value) {
            return parsed
        }
        return iso8601.date(from: value)
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func migrateLegacyWrapperTokenIfNeeded() {
        guard credentialStore.loadWrapperToken() == nil else { return }
        guard let legacyToken = UserDefaults.standard.string(forKey: Self.legacyWrapperTokenKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !legacyToken.isEmpty
        else {
            UserDefaults.standard.removeObject(forKey: Self.legacyWrapperTokenKey)
            return
        }
        credentialStore.saveWrapperToken(legacyToken)
        UserDefaults.standard.removeObject(forKey: Self.legacyWrapperTokenKey)
    }

    @discardableResult
    private func refreshTokenFromStoredCredentials(reason: String) async -> Bool {
        debugMetrics.refreshAttempts += 1
        debugMetrics.lastRefreshAt = Date()
        debugMetrics.lastRefreshReason = reason

        guard let credentials = credentialStore.load() else {
            debugMetrics.refreshFailures += 1
            debugMetrics.lastErrorMessage = "No stored credentials for refresh"
            return false
        }

        do {
            let result = try await loginEnsuringValidDlcAccount(
                muid: credentials.muid,
                mpassword: credentials.mpassword
            )
            applyLoggedInState(token: result.wrapperToken, dlcConnected: result.dlcConnected)
            debugMetrics.refreshSuccesses += 1
            return true
        } catch let authError as AuthError {
            if case .invalidCredentials = authError {
                credentialStore.clear()
            }
            debugMetrics.refreshFailures += 1
            debugMetrics.lastErrorMessage = authError.localizedDescription
            return false
        } catch {
            debugMetrics.refreshFailures += 1
            debugMetrics.lastErrorMessage = error.localizedDescription
            return false
        }
    }

    private func loginEnsuringValidDlcAccount(
        muid: String,
        mpassword: String
    ) async throws -> LoginResponseData {
        let result: LoginResponseData
        do {
            debugMetrics.tokenLoginAttempts += 1
            debugMetrics.lastLoginAttemptAt = Date()
            result = try await AuthService.login(muid: muid, mpassword: mpassword)
            debugMetrics.tokenLoginSuccesses += 1
        } catch {
            debugMetrics.tokenLoginFailures += 1
            debugMetrics.lastErrorMessage = error.localizedDescription
            throw error
        }

        do {
            debugMetrics.dlcProfileChecks += 1
            let profile = try await APIService.fetchDlcProfile(token: result.wrapperToken)
            if isValidDlcAccount(profile.account) {
                debugMetrics.lastSuccessfulLoginAt = Date()
                return result
            }
            debugMetrics.dlcProfileInvalidCount += 1
            debugMetrics.lastErrorMessage = "DLC 帳號狀態無效，請稍後再試"
            throw AuthError.serverError("DLC 帳號狀態無效，請稍後再試")
        } catch {
            debugMetrics.lastErrorMessage = error.localizedDescription
            throw error
        }
    }

    private func isValidDlcAccount(_ account: String?) -> Bool {
        guard let account else { return false }
        let normalized = account.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !normalized.isEmpty && normalized != "guest"
    }
}
