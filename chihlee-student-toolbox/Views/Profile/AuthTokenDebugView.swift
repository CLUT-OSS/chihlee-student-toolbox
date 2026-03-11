import SwiftUI
import SwiftData
import UIKit

struct AuthTokenDebugView: View {
    let token: String?
    let metrics: AuthDebugMetrics

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showCopiedAlert = false
    @State private var cfRay: String?
    @State private var traceFields: [(key: String, value: String)] = []
    @State private var isLoadingTrace = false
    @State private var isTriggeringLiveActivity = false
    @State private var liveActivityDebugMessage: String?

    private var tokenText: String {
        guard let token, !token.isEmpty else { return "No token found" }
        return token
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Current Auth Token")
                        .font(.headline)

                    Text(tokenText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.system(.footnote, design: .monospaced))
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture { copyToken() }

                    metricsPanel

                    proxyMetricsPanel

                    liveActivityDebugPanel

                    Button {
                        copyToken()
                    } label: {
                        Label("Copy Token", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(token?.isEmpty ?? true)
                }
                .padding()
            }
            .navigationTitle("Debug")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Token copied", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) {}
            }
            .task { await fetchTrace() }
        }
    }

    private var metricsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Auth Metrics")
                .font(.headline)

            Group {
                metricRow("User Login Requests", "\(metrics.userLoginRequests)")
                metricRow("Token Login Attempts", "\(metrics.tokenLoginAttempts)")
                metricRow("Token Login Successes", "\(metrics.tokenLoginSuccesses)")
                metricRow("Token Login Failures", "\(metrics.tokenLoginFailures)")
                metricRow("DLC Profile Checks", "\(metrics.dlcProfileChecks)")
                metricRow("DLC Invalid Account Count", "\(metrics.dlcProfileInvalidCount)")
                metricRow("Session Validation Runs", "\(metrics.sessionValidationRuns)")
                metricRow("Session Check Calls", "\(metrics.sessionCheckCalls)")
                metricRow("Session Check Successes", "\(metrics.sessionCheckSuccesses)")
                metricRow("Session Check Failures", "\(metrics.sessionCheckFailures)")
                metricRow("Refresh Attempts", "\(metrics.refreshAttempts)")
                metricRow("Refresh Successes", "\(metrics.refreshSuccesses)")
                metricRow("Refresh Failures", "\(metrics.refreshFailures)")
                metricRow("Last Session Validation", formatDate(metrics.lastSessionValidationAt))
                metricRow("Last Login Attempt", formatDate(metrics.lastLoginAttemptAt))
                metricRow("Last Successful Login", formatDate(metrics.lastSuccessfulLoginAt))
                metricRow("Last Refresh", formatDate(metrics.lastRefreshAt))
                metricRow("Last Refresh Reason", metrics.lastRefreshReason ?? "-")
                metricRow("Last Error", metrics.lastErrorMessage ?? "-")
            }
        }
        .font(.system(.footnote, design: .monospaced))
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func metricRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(key)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "-" }
        return Self.timestampFormatter.string(from: date)
    }

    private var proxyMetricsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Proxy Metrics")
                    .font(.headline)
                Spacer()
                if isLoadingTrace {
                    ProgressView().controlSize(.mini)
                }
            }

            if let cfRay {
                metricRow("CF-Ray", cfRay)
            }

            ForEach(traceFields, id: \.key) { field in
                metricRow(field.key, field.value)
            }

            if !isLoadingTrace && cfRay == nil && traceFields.isEmpty {
                Text("Failed to load trace")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(.footnote, design: .monospaced))
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var liveActivityDebugPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Live Activity Debug")
                .font(.headline)

            HStack(spacing: 8) {
                Button("Before Class") {
                    Task { await triggerLiveActivityDebug(.countdown) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isTriggeringLiveActivity)

                Button("In Class") {
                    Task { await triggerLiveActivityDebug(.inClass) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isTriggeringLiveActivity)

                Button("End") {
                    Task {
                        isTriggeringLiveActivity = true
                        await ClassLiveActivityCoordinator.shared.endAllActivities()
                        liveActivityDebugMessage = "Ended all class Live Activities"
                        isTriggeringLiveActivity = false
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isTriggeringLiveActivity)
            }

            if let liveActivityDebugMessage {
                Text(liveActivityDebugMessage)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(.footnote, design: .monospaced))
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func fetchTrace() async {
        isLoadingTrace = true
        defer { isLoadingTrace = false }

        guard let url = URL(string: "\(AuthService.baseURL)/cdn-cgi/trace") else { return }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse
        else { return }

        cfRay = http.value(forHTTPHeaderField: "cf-ray")

        guard let text = String(data: data, encoding: .utf8) else { return }

        let displayKeys = ["ip", "colo", "loc", "http", "tls", "kex", "uag", "ts", "fl", "warp", "sliver"]
        traceFields = text
            .components(separatedBy: .newlines)
            .compactMap { line -> (key: String, value: String)? in
                let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
                guard parts.count == 2, displayKeys.contains(parts[0]) else { return nil }
                return (key: parts[0], value: parts[1])
            }
            .sorted { displayKeys.firstIndex(of: $0.key) ?? 99 < displayKeys.firstIndex(of: $1.key) ?? 99 }
    }

    private func copyToken() {
        guard let token, !token.isEmpty else { return }
        UIPasteboard.general.string = token
        showCopiedAlert = true
    }

    @MainActor
    private func triggerLiveActivityDebug(_ phase: ClassLiveActivityAttributes.ClassPhase) async {
        isTriggeringLiveActivity = true
        let result = await ClassLiveActivityCoordinator.shared.debugStartSimulation(phase: phase, context: modelContext)
        liveActivityDebugMessage = result
        isTriggeringLiveActivity = false
    }
}
