import Foundation
import SwiftData

#if canImport(ActivityKit)
import ActivityKit
#endif

@MainActor
final class ClassLiveActivityCoordinator {
    static let shared = ClassLiveActivityCoordinator()

    private init() {}

    func refresh(now: Date = Date(), context: ModelContext, enabled: Bool) async {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *), enabled, ActivityAuthorizationInfo().areActivitiesEnabled else {
            await endAllActivities()
            return
        }

        let sessions = (try? context.fetch(FetchDescriptor<ClassSession>())) ?? []
        let entries = ClassLiveActivityEngine.timelineEntries(now: now, sessions: sessions)
        let snapshot = ClassLiveActivityEngine.snapshot(now: now, entries: entries)

        guard let snapshot else {
            await endAllActivities()
            return
        }

        let activities = Activity<ClassLiveActivityAttributes>.activities

        if let current = activities.first(where: { $0.attributes.sessionID == snapshot.sessionID }) {
            for other in activities where other.id != current.id {
                await other.end(nil, dismissalPolicy: .immediate)
            }

            let nextState = makeContentState(from: snapshot)
            if current.content.state != nextState {
                let content = ActivityContent(state: nextState, staleDate: snapshot.phaseEnd)
                await current.update(content)
            }
            return
        }

        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        let attributes = ClassLiveActivityAttributes(
            sessionID: snapshot.sessionID,
            courseName: snapshot.courseName,
            classroom: snapshot.classroom,
            teacher: snapshot.teacher,
            classStart: snapshot.classStart,
            classEnd: snapshot.classEnd
        )

        let content = ActivityContent(state: makeContentState(from: snapshot), staleDate: snapshot.phaseEnd)

        do {
            _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
        } catch {
            #if DEBUG
            print("Failed to request class Live Activity: \(error.localizedDescription)")
            #endif
        }
        #endif
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
        context: ModelContext
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
        let duration = classDuration(for: primary)
        let classStart: Date
        let classEnd: Date
        let phaseStart: Date
        let phaseEnd: Date

        switch phase {
        case .countdown:
            classStart = now.addingTimeInterval(15 * 60)
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

    private func makeContentState(from snapshot: ClassLiveActivitySnapshot) -> ClassLiveActivityAttributes.ContentState {
        ClassLiveActivityAttributes.ContentState(
            phase: snapshot.phase,
            courseName: snapshot.courseName,
            classroom: snapshot.classroom,
            teacher: snapshot.teacher,
            classStart: snapshot.classStart,
            classEnd: snapshot.classEnd,
            phaseStart: snapshot.phaseStart,
            phaseEnd: snapshot.phaseEnd,
            nextCourseName: snapshot.nextCourseName,
            nextStart: snapshot.nextStart,
            nextClassroom: snapshot.nextClassroom
        )
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
}
