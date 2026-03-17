import Foundation
import SwiftData

#if canImport(ActivityKit)
import ActivityKit
#endif

private let liveActivityCurrentPushToStartTokenUserDefaultsKey = "liveActivityCurrentPushToStartToken"
private let liveActivityLastSyncedPushToStartTokenUserDefaultsKey = "liveActivityLastSyncedPushToStartToken"

@MainActor
final class ClassLiveActivityCoordinator {
    static let shared = ClassLiveActivityCoordinator()
    static let remoteDebugKeyUserDefaultsKey = "liveActivityDebugKey"
    static let currentPushToStartTokenUserDefaultsKey = liveActivityCurrentPushToStartTokenUserDefaultsKey
    static let lastSyncedPushToStartTokenUserDefaultsKey = liveActivityLastSyncedPushToStartTokenUserDefaultsKey

    private var remoteSyncTask: Task<Void, Never>?
    private var remoteSyncToken: String?

    private init() {}

    func refresh(now: Date = Date(), context: ModelContext, enabled: Bool) async {
        #if canImport(ActivityKit)
        _ = now
        _ = context
        await updateRemoteSync(token: UserDefaults.standard.string(forKey: "wrapperToken"), enabled: enabled)
        #else
        _ = now
        _ = context
        _ = enabled
        #endif
    }

    func updateRemoteSync(
        token: String?,
        enabled: Bool,
        forceRegisterOnStart: Bool = false
    ) async {
        #if canImport(ActivityKit)
        guard #available(iOS 17.2, *),
              enabled,
              ActivityAuthorizationInfo().areActivitiesEnabled,
              let authToken = Self.normalized(token),
              let idfv = Self.normalized(AuthService.identifierForVendor),
              let bundleID = Self.normalized(Bundle.main.bundleIdentifier)
        else {
            stopRemoteSync()
            Task {
                await self.endAllActivities()
            }
            return
        }

        if remoteSyncTask != nil, remoteSyncToken == authToken {
            return
        }

        stopRemoteSync()
        remoteSyncToken = authToken
        remoteSyncTask = Task(priority: .background) {
            await Self.observePushToStartTokenUpdates(
                authToken: authToken,
                idfv: idfv,
                bundleID: bundleID,
                forceRegisterFirstToken: forceRegisterOnStart
            )
        }
        #else
        _ = token
        _ = enabled
        _ = forceRegisterOnStart
        #endif
    }

    func registerRemoteDeviceIfPossible(token: String?) async -> Bool {
        #if canImport(ActivityKit)
        guard #available(iOS 17.2, *),
              let authToken = Self.normalized(token),
              let idfv = Self.normalized(AuthService.identifierForVendor),
              let bundleID = Self.normalized(Bundle.main.bundleIdentifier),
              let pushToStartToken = Self.currentOrCachedPushToStartToken()
        else {
            return false
        }

        UserDefaults.standard.set(
            pushToStartToken,
            forKey: liveActivityCurrentPushToStartTokenUserDefaultsKey
        )

        do {
            try await Self.registerOrPatchLiveActivityDevice(
                authToken: authToken,
                idfv: idfv,
                bundleID: bundleID,
                pushToStartToken: pushToStartToken
            )
            UserDefaults.standard.set(
                pushToStartToken,
                forKey: liveActivityLastSyncedPushToStartTokenUserDefaultsKey
            )
            return true
        } catch is CancellationError {
            return false
        } catch {
            #if DEBUG
            print("Live Activity register failed: \(error.localizedDescription)")
            #endif
            return false
        }
        #else
        _ = token
        return false
        #endif
    }

    func forceRegisterRemoteDevice(token: String?) async -> String {
        #if canImport(ActivityKit)
        guard #available(iOS 17.2, *) else {
            return "Live Activity remote register requires iOS 17.2+"
        }
        guard let authToken = Self.normalized(token) else {
            return "Missing auth token"
        }
        guard let idfv = Self.normalized(AuthService.identifierForVendor) else {
            return "Missing IDFV"
        }
        guard let bundleID = Self.normalized(Bundle.main.bundleIdentifier) else {
            return "Missing bundle ID"
        }
        Task {
            await self.updateRemoteSync(token: token, enabled: true, forceRegisterOnStart: true)
        }
        guard let pushToStartToken = Self.currentOrCachedPushToStartToken() else {
            return "No push-to-start token available yet"
        }

        UserDefaults.standard.set(
            pushToStartToken,
            forKey: liveActivityCurrentPushToStartTokenUserDefaultsKey
        )

        do {
            try await Self.registerOrPatchLiveActivityDevice(
                authToken: authToken,
                idfv: idfv,
                bundleID: bundleID,
                pushToStartToken: pushToStartToken
            )
            UserDefaults.standard.set(
                pushToStartToken,
                forKey: liveActivityLastSyncedPushToStartTokenUserDefaultsKey
            )
            return "Force register sent"
        } catch let error as AuthError {
            return error.localizedDescription
        } catch {
            return "Force register failed: \(error.localizedDescription)"
        }
        #else
        _ = token
        return "ActivityKit is unavailable on this build"
        #endif
    }

    func stopRemoteSync() {
        remoteSyncTask?.cancel()
        remoteSyncTask = nil
        remoteSyncToken = nil
    }

    func unregisterRemoteDevice(token: String?) async {
        guard let authToken = Self.normalized(token),
              let idfv = Self.normalized(AuthService.identifierForVendor)
        else {
            return
        }

        do {
            _ = try await APIService.unregisterLiveActivityDevice(
                token: authToken,
                idfv: idfv,
                bundleID: Self.normalized(Bundle.main.bundleIdentifier)
            )
        } catch is CancellationError {
            return
        } catch {
            #if DEBUG
            print("Live Activity unregister failed: \(error.localizedDescription)")
            #endif
        }
    }

    func endAllActivities() async {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }
        for activity in Activity<ClassLiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        #endif
    }

    func debugStartSimulation(
        phase: ClassLiveActivityAttributes.ClassPhase,
        context: ModelContext,
        countdownLeadTimeOverride: TimeInterval? = nil,
        classDurationOverride: TimeInterval? = nil
    ) async -> String {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else {
            return "Live Activity requires iOS 16.2+"
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return "Live Activities are disabled on this device"
        }

        let sessions = (try? context.fetch(FetchDescriptor<ClassSession>())) ?? []
        guard let primary = sessions.first else {
            return "No class sessions found. Sync schedule first."
        }

        let now = Date()
        let countdownLeadTime = max(5, countdownLeadTimeOverride ?? 15 * 60)
        let duration = max(5, classDurationOverride ?? classDuration(for: primary))
        let classStart: Date
        let classEnd: Date
        let phaseStart: Date
        let phaseEnd: Date

        switch phase {
        case .countdown:
            classStart = now.addingTimeInterval(countdownLeadTime)
            classEnd = classStart.addingTimeInterval(duration)
            phaseStart = now
            phaseEnd = classStart
        case .inClass:
            classStart = now
            classEnd = classStart.addingTimeInterval(duration)
            phaseStart = classStart
            phaseEnd = classEnd
        }

        let next = sessions.first(where: { $0 !== primary })
        let nextCourseName = normalizedCourseName(from: next)
        let nextClassroom = next?.classroom.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextStart = next == nil ? nil : classEnd.addingTimeInterval(10 * 60)

        let attributes = ClassLiveActivityAttributes(
            sessionID: "debug|\(phase.rawValue)|\(Int(now.timeIntervalSince1970))",
            courseName: normalizedCourseName(from: primary),
            classroom: primary.classroom.trimmingCharacters(in: .whitespacesAndNewlines),
            teacher: (primary.course?.instructor ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            classStart: classStart,
            classEnd: classEnd
        )

        let state = ClassLiveActivityAttributes.ContentState(
            phase: phase,
            courseName: attributes.courseName,
            classroom: attributes.classroom,
            teacher: attributes.teacher,
            classStart: classStart,
            classEnd: classEnd,
            phaseStart: phaseStart,
            phaseEnd: phaseEnd,
            nextCourseName: nextCourseName,
            nextStart: nextStart,
            nextClassroom: nextClassroom
        )

        await endAllActivities()

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: phaseEnd),
                pushType: nil
            )
            return phase == .countdown ? "Started debug Live Activity: before class" : "Started debug Live Activity: in class"
        } catch {
            return "Failed to start debug Live Activity: \(error.localizedDescription)"
        }
        #else
        return "ActivityKit is unavailable on this build"
        #endif
    }

    func debugStartRemoteSimulation(
        phase: ClassLiveActivityAttributes.ClassPhase,
        context: ModelContext,
        token: String?
    ) async -> String {
        _ = phase
        _ = context

        guard let authToken = Self.normalized(token) else {
            return "Missing auth token"
        }
        guard let debugKey = Self.normalized(
            UserDefaults.standard.string(forKey: Self.remoteDebugKeyUserDefaultsKey)
        ) else {
            return "Missing Live Activity debug key"
        }

        do {
            let run = try await APIService.triggerLiveActivityDebug(token: authToken, debugKey: debugKey)
            return "Triggered remote debug run \(run.runID) (\(run.targetDevices) devices)"
        } catch let error as AuthError {
            return error.localizedDescription
        } catch {
            return "Failed to trigger remote debug: \(error.localizedDescription)"
        }
    }

    @available(iOS 17.2, *)
    nonisolated private static func observePushToStartTokenUpdates(
        authToken: String,
        idfv: String,
        bundleID: String,
        forceRegisterFirstToken: Bool
    ) async {
        var lastSyncedToken: String?
        var shouldForceRegister = forceRegisterFirstToken

        for await tokenData in Activity<ClassLiveActivityAttributes>.pushToStartTokenUpdates {
            if Task.isCancelled {
                return
            }

            let pushToStartToken = tokenData.map { String(format: "%02x", $0) }.joined()
            guard !pushToStartToken.isEmpty else { continue }
            UserDefaults.standard.set(
                pushToStartToken,
                forKey: liveActivityCurrentPushToStartTokenUserDefaultsKey
            )
            guard pushToStartToken != lastSyncedToken else { continue }

            do {
                if shouldForceRegister {
                    try await Self.registerOrPatchLiveActivityDevice(
                        authToken: authToken,
                        idfv: idfv,
                        bundleID: bundleID,
                        pushToStartToken: pushToStartToken
                    )
                    shouldForceRegister = false
                } else {
                    let patchOutcome = try await APIService.patchLiveActivityToken(
                        token: authToken,
                        idfv: idfv,
                        pushToStartToken: pushToStartToken
                    )
                    if case .needsRegisterFallback = patchOutcome {
                        try await APIService.registerLiveActivityDevice(
                            token: authToken,
                            idfv: idfv,
                            bundleID: bundleID,
                            pushToStartToken: pushToStartToken
                        )
                    }
                }
                lastSyncedToken = pushToStartToken
                UserDefaults.standard.set(
                    pushToStartToken,
                    forKey: liveActivityLastSyncedPushToStartTokenUserDefaultsKey
                )
            } catch is CancellationError {
                return
            } catch {
                #if DEBUG
                print("Live Activity token sync failed: \(error.localizedDescription)")
                #endif
            }
        }
    }

    nonisolated private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    @available(iOS 17.2, *)
    nonisolated private static func currentOrCachedPushToStartToken() -> String? {
        if let tokenData = Activity<ClassLiveActivityAttributes>.pushToStartToken {
            let token = tokenData.map { String(format: "%02x", $0) }.joined()
            if !token.isEmpty {
                return token
            }
        }

        if let cachedCurrent = normalized(
            UserDefaults.standard.string(forKey: liveActivityCurrentPushToStartTokenUserDefaultsKey)
        ) {
            return cachedCurrent
        }
        return normalized(
            UserDefaults.standard.string(forKey: liveActivityLastSyncedPushToStartTokenUserDefaultsKey)
        )
    }

    @available(iOS 17.2, *)
    nonisolated private static func registerOrPatchLiveActivityDevice(
        authToken: String,
        idfv: String,
        bundleID: String,
        pushToStartToken: String
    ) async throws {
        do {
            try await APIService.registerLiveActivityDevice(
                token: authToken,
                idfv: idfv,
                bundleID: bundleID,
                pushToStartToken: pushToStartToken
            )
            return
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            let patchOutcome = try await APIService.patchLiveActivityToken(
                token: authToken,
                idfv: idfv,
                pushToStartToken: pushToStartToken
            )
            if case .patched = patchOutcome {
                return
            }
            throw error
        }
    }

    private func classDuration(for session: ClassSession) -> TimeInterval {
        guard let period = ScheduleViewModel.periods(for: session.dayOfWeek).first(where: { $0.code == session.periodCode }) else {
            return 50 * 60
        }
        let startMinutes = period.startHour * 60 + period.startMinute
        let endMinutes = period.endHour * 60 + period.endMinute
        return TimeInterval(max(30, endMinutes - startMinutes) * 60)
    }

    private func normalizedCourseName(from session: ClassSession?) -> String {
        let raw = (session?.course?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? "未命名課程" : raw
    }

    deinit {
        remoteSyncTask?.cancel()
    }
}
