import SwiftUI
import SwiftData

struct ToolkitTabView: View {
    private struct ToolItem: Identifiable {
        let id: String
        let name: String
        let icon: String
        let color: Color
    }

    private let tools: [ToolItem] = [
        ToolItem(id: "gpa", name: "GPA 計算機", icon: "function", color: .blue),
        ToolItem(id: "links", name: "常用連結", icon: "link", color: .green),
        ToolItem(id: "calendar", name: "學校行事曆", icon: "calendar", color: .orange),
        ToolItem(id: "library", name: "圖書館掃描", icon: "barcode.viewfinder", color: .indigo),
        ToolItem(id: "scores", name: "歷年成績", icon: "doc.text.magnifyingglass", color: .teal),
        ToolItem(id: "leave", name: "請假申請", icon: "cross.case", color: .cyan),
    ]

    var body: some View {
        NavigationStack {
            toolboxGrid
        }
    }

    private var toolboxGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(tools) { tool in
                        NavigationLink {
                            destinationView(for: tool.id)
                        } label: {
                            toolCard(name: tool.name, icon: tool.icon, color: tool.color)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
        .navigationTitle("工具箱")
        .navigationBarTitleDisplayMode(.large)
    }

    private func toolCard(name: String, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(color)
            Text(name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func destinationView(for toolID: String) -> some View {
        switch toolID {
        case "gpa":
            GPACalculatorView()
        case "links":
            QuickLinksView()
        case "calendar":
            SchoolCalendarView()
        case "library":
            LibraryScanView()
        case "scores":
            TranscriptView()
        case "leave":
            LeaveApplicationView()
        default:
            EmptyView()
        }
    }
}

#if DEBUG
#Preview {
    ToolkitTabView()
}
#endif

private struct SchoolCalendarSection: Identifiable {
    let date: Date
    let events: [DlcCalendarEvent]

    var id: Date { DateHelper.calendar.startOfDay(for: date) }
    var title: String { DateHelper.daySectionTitle(date) }
}

struct SchoolCalendarView: View {
    @State private var events: [DlcCalendarEvent] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var sections: [SchoolCalendarSection] {
        let sortedEvents = events.sorted { lhs, rhs in
            let lhsDate = lhs.date ?? .distantFuture
            let rhsDate = rhs.date ?? .distantFuture
            if lhsDate == rhsDate {
                return lhs.displaySubject < rhs.displaySubject
            }
            return lhsDate < rhsDate
        }

        let grouped = Dictionary(grouping: sortedEvents) { event in
            DateHelper.calendar.startOfDay(for: event.date ?? .distantFuture)
        }
        return grouped
            .map { key, value in
                SchoolCalendarSection(date: key, events: value)
            }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        Group {
            if isLoading && events.isEmpty {
                ProgressView("載入學校行事曆...")
            } else if sections.isEmpty {
                ContentUnavailableView(
                    "沒有學校行事曆資料",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text(errorMessage ?? "請稍後再試")
                )
            } else {
                List {
                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ForEach(sections) { section in
                        Section {
                            ForEach(section.events) { event in
                                DlcEventRow(event: event)
                            }
                        } header: {
                            Text(section.title)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("學校行事曆")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await loadEvents(force: true) }
                } label: {
                    if isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(isLoading)
            }
        }
        .task {
            await loadEvents(force: true)
        }
    }

    @MainActor
    private func loadEvents(force: Bool) async {
        if isLoading { return }
        if !force, !events.isEmpty { return }

        isLoading = true
        defer { isLoading = false }

        do {
            events = try await APIService.fetchSchoolCalendarEvents()
            errorMessage = nil
        } catch {
            if events.isEmpty {
                errorMessage = "載入失敗：\(error.localizedDescription)"
            } else {
                errorMessage = "更新失敗：\(error.localizedDescription)"
            }
        }
    }
}

struct LibraryScanView: View {
    @Query private var students: [Student]
    @State private var previousBrightness: CGFloat = UIScreen.main.brightness
    @State private var brightnessTimer: Timer?

    var body: some View {
        GeometryReader { geometry in
            let barcodeWidth = max(180, geometry.size.width * 0.6)
            let barcodeHeight = geometry.size.height

            ZStack(alignment: .top) {
                if let code39Value {
                    Code39BarcodeView(code: code39Value)
                        .frame(width: barcodeWidth, height: barcodeHeight)
                        .rotationEffect(.degrees(180))
                        .accessibilityLabel("圖書館掃描條碼")
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ContentUnavailableView(
                        "找不到學號",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text("請先完成登入或個人資料同步")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.ignoresSafeArea())
        }
        .navigationTitle("圖書館掃描")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            previousBrightness = UIScreen.main.brightness
            animateBrightness(to: 1.0)
        }
        .onDisappear {
            animateBrightness(to: previousBrightness)
        }
    }

    private func animateBrightness(to target: CGFloat, duration: TimeInterval = 0.5) {
        brightnessTimer?.invalidate()
        let start = UIScreen.main.brightness
        let startTime = Date()
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = CGFloat(min(elapsed / duration, 1.0))
            UIScreen.main.brightness = start + (target - start) * progress
            if progress >= 1.0 {
                timer.invalidate()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        brightnessTimer = timer
    }

    private var code39Value: String? {
        let raw = students
            .map(\.studentID)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""
        let normalized = raw.uppercased()
        let allowed = Set("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-. $/+%")
        let filtered = String(normalized.filter { allowed.contains($0) })
        return filtered.isEmpty ? nil : filtered
    }
}

private struct Code39Element: Identifiable {
    let id = UUID()
    let isBar: Bool
    let unit: Int
}

private struct Code39BarcodeView: View {
    let code: String

    private static let patterns: [Character: String] = [
        "0": "nnnwwnwnn", "1": "wnnwnnnnw", "2": "nnwwnnnnw", "3": "wnwwnnnnn",
        "4": "nnnwwnnnw", "5": "wnnwwnnnn", "6": "nnwwwnnnn", "7": "nnnwnnwnw",
        "8": "wnnwnnwnn", "9": "nnwwnnwnn", "A": "wnnnnwnnw", "B": "nnwnnwnnw",
        "C": "wnwnnwnnn", "D": "nnnnwwnnw", "E": "wnnnwwnnn", "F": "nnwnwwnnn",
        "G": "nnnnnwwnw", "H": "wnnnnwwnn", "I": "nnwnnwwnn", "J": "nnnnwwwnn",
        "K": "wnnnnnnww", "L": "nnwnnnnww", "M": "wnwnnnnwn", "N": "nnnnwnnww",
        "O": "wnnnwnnwn", "P": "nnwnwnnwn", "Q": "nnnnnnwww", "R": "wnnnnnwwn",
        "S": "nnwnnnwwn", "T": "nnnnwnwwn", "U": "wwnnnnnnw", "V": "nwwnnnnnw",
        "W": "wwwnnnnnn", "X": "nwnnwnnnw", "Y": "wwnnwnnnn", "Z": "nwwnwnnnn",
        "-": "nwnnnnwnw", ".": "wwnnnnwnn", " ": "nwwnnnwnn", "*": "nwnnwnwnn",
        "$": "nwnwnwnnn", "/": "nwnwnnnwn", "+": "nwnnnwnwn", "%": "nnnwnwnwn",
    ]

    var body: some View {
        GeometryReader { geometry in
            let elements = Self.makeElements(from: code)
            let totalUnits = max(1, elements.reduce(0) { $0 + $1.unit })

            HStack(spacing: 0) {
                ForEach(elements) { element in
                    (element.isBar ? Color.black : Color.white)
                        .frame(
                            width: geometry.size.width * CGFloat(element.unit) / CGFloat(totalUnits),
                            height: geometry.size.height
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color.white)
        .clipped()
    }

    private static func makeElements(from payload: String) -> [Code39Element] {
        let encoded = "*" + payload + "*"
        let chars = Array(encoded)
        var result: [Code39Element] = []

        for (index, character) in chars.enumerated() {
            guard let pattern = patterns[character] else { continue }
            let tokens = Array(pattern)
            for tokenIndex in tokens.indices {
                let isBar = tokenIndex % 2 == 0
                let unit = tokens[tokenIndex] == "w" ? 3 : 1
                result.append(Code39Element(isBar: isBar, unit: unit))
            }

            if index < chars.count - 1 {
                result.append(Code39Element(isBar: false, unit: 1))
            }
        }
        return result
    }
}
