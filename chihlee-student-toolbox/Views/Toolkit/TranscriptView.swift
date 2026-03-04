import SwiftUI

// MARK: - TranscriptView

struct TranscriptView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var semesters: [APISemesterScore] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var openSemester: Int? = nil
    @State private var openCourse: [Int: Int] = [:]

    var body: some View {
        Group {
            if isLoading && semesters.isEmpty {
                ProgressView("載入成績中…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage, semesters.isEmpty {
                ContentUnavailableView {
                    Label("載入失敗", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("重試") {
                        Task { await load() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if semesters.isEmpty {
                ContentUnavailableView("尚無成績資料", systemImage: "doc.text.magnifyingglass")
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(semesters.enumerated()), id: \.element.semester) { semIdx, sem in
                            SemesterCardView(
                                semester: sem,
                                isOpen: openSemester == semIdx,
                                openCourseIndex: openCourse[semIdx],
                                onToggleSemester: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        if openSemester == semIdx {
                                            openSemester = nil
                                            openCourse.removeValue(forKey: semIdx)
                                        } else {
                                            openSemester = semIdx
                                            openCourse.removeValue(forKey: semIdx)
                                        }
                                    }
                                },
                                onToggleCourse: { courseIdx in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if openCourse[semIdx] == courseIdx {
                                            openCourse.removeValue(forKey: semIdx)
                                        } else {
                                            openCourse[semIdx] = courseIdx
                                        }
                                    }
                                },
                                gradeColor: gradeColor,
                                categoryColor: categoryColor
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("歷年成績")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await load() }
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
        .task { await load() }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            semesters = try await APIService.fetchScores(token: auth.wrapperToken ?? "")
            openSemester = nil
            openCourse = [:]
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func gradeColor(_ raw: String?) -> Color {
        guard let s = raw?.trimmingCharacters(in: .whitespaces), !s.isEmpty else {
            return ColorHelper.color(from: "#475569")
        }
        let specialTerms = ["停修", "未開放", "未登錄", "修讀中", "尚無", "--"]
        if specialTerms.contains(where: { s.contains($0) }) {
            return ColorHelper.color(from: "#475569")
        }
        let numStr = s.hasPrefix("*") ? String(s.dropFirst()) : s
        guard let n = Double(numStr) else { return ColorHelper.color(from: "#475569") }
        switch n {
        case 90...: return ColorHelper.color(from: "#4ade80")
        case 80...: return ColorHelper.color(from: "#60a5fa")
        case 70...: return ColorHelper.color(from: "#facc15")
        case 60...: return ColorHelper.color(from: "#fb923c")
        default:    return ColorHelper.color(from: "#f87171")
        }
    }

    private func categoryColor(_ cat: String?) -> Color {
        switch cat {
        case "必修": return ColorHelper.color(from: "#93c5fd")
        case "必重": return ColorHelper.color(from: "#fca5a5")
        case "選修": return ColorHelper.color(from: "#d8b4fe")
        case "通識": return ColorHelper.color(from: "#86efac")
        default:    return .gray.opacity(0.3)
        }
    }
}

// MARK: - SemesterCardView

private struct SemesterCardView: View {
    let semester: APISemesterScore
    let isOpen: Bool
    let openCourseIndex: Int?
    let onToggleSemester: () -> Void
    let onToggleCourse: (Int) -> Void
    let gradeColor: (String?) -> Color
    let categoryColor: (String?) -> Color

    private var courseCount: Int { semester.courses.count }
    private var totalCredits: Double { semester.courses.compactMap(\.credits).reduce(0, +) }

    private var semAvgDisplay: String? {
        semester.summary?.semesterAvg.flatMap {
            let s = $0.trimmingCharacters(in: .whitespaces)
            return s.isEmpty ? nil : s
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: onToggleSemester) {
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(semester.semesterTitle)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        HStack(spacing: 8) {
                            Text("\(courseCount) 科")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if totalCredits > 0 {
                                Text("共 \(String(format: "%.0f", totalCredits)) 學分")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        if let avg = semAvgDisplay {
                            Text(avg)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(gradeColor(avg))
                        } else {
                            Text("成績未公布")
                                .font(.footnote)
                                .foregroundStyle(ColorHelper.color(from: "#475569"))
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isOpen ? 90 : 0))
                            .animation(.easeInOut(duration: 0.25), value: isOpen)
                    }
                }
                .padding()
            }
            .buttonStyle(.plain)

            if isOpen {
                Divider().padding(.horizontal)

                VStack(spacing: 0) {
                    if let summary = semester.summary, hasMeaningfulSummary(summary) {
                        SummaryBar(summary: summary, gradeColor: gradeColor)
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                        Divider().padding(.horizontal)
                    }

                    ForEach(Array(semester.courses.enumerated()), id: \.offset) { courseIdx, course in
                        CourseRowView(
                            course: course,
                            isOpen: openCourseIndex == courseIdx,
                            onToggle: { onToggleCourse(courseIdx) },
                            gradeColor: gradeColor,
                            categoryColor: categoryColor
                        )
                        if courseIdx < semester.courses.count - 1 {
                            Divider().padding(.leading)
                        }
                    }
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func hasMeaningfulSummary(_ s: APIScoreSummary) -> Bool {
        let values = [s.semesterAvg, s.regularAvg, s.midtermAvg, s.creditsTaken, s.creditsEarned, s.conductScore]
        return values.contains { v in
            guard let v else { return false }
            let t = v.trimmingCharacters(in: .whitespaces)
            return !t.isEmpty && t != "--"
        }
    }
}

// MARK: - SummaryBar

private struct SummaryBar: View {
    let summary: APIScoreSummary
    let gradeColor: (String?) -> Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                if let v = nonEmpty(summary.regularAvg) {
                    summaryCell(label: "平時均", value: v)
                }
                if let v = nonEmpty(summary.midtermAvg) {
                    summaryCell(label: "期中均", value: v)
                }
                if let v = nonEmpty(summary.semesterAvg) {
                    summaryCell(label: "學期均", value: v)
                }
                if let v = nonEmpty(summary.conductScore) {
                    summaryCell(label: "品德", value: v)
                }
                if let taken = nonEmpty(summary.creditsTaken), let earned = nonEmpty(summary.creditsEarned) {
                    VStack(spacing: 2) {
                        Text("\(earned)/\(taken)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("取/修學分")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func summaryCell(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(gradeColor(value))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func nonEmpty(_ s: String?) -> String? {
        guard let s else { return nil }
        let t = s.trimmingCharacters(in: .whitespaces)
        return (t.isEmpty || t == "--") ? nil : t
    }
}

// MARK: - CourseRowView

private struct CourseRowView: View {
    let course: APICourseScore
    let isOpen: Bool
    let onToggle: () -> Void
    let gradeColor: (String?) -> Color
    let categoryColor: (String?) -> Color

    private var isRetake: Bool { course.total?.hasPrefix("*") ?? false }
    private var totalDisplay: String? {
        guard let t = course.total?.trimmingCharacters(in: .whitespaces), !t.isEmpty else { return nil }
        return t.hasPrefix("*") ? String(t.dropFirst()) : t
    }

    var body: some View {
        VStack(spacing: 0) {
            // Collapsed header
            Button(action: onToggle) {
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(course.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            if let cat = course.category {
                                Text(cat)
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(categoryColor(cat).opacity(0.25))
                                    .foregroundStyle(categoryColor(cat))
                                    .clipShape(Capsule())
                            }
                            if let teacher = course.teacher, !teacher.isEmpty {
                                Text(teacher)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            if let credits = course.credits {
                                Text("\(String(format: credits == credits.rounded() ? "%.0f" : "%.1f", credits)) 學分")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        if isRetake {
                            Text("補考")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.15))
                                .foregroundStyle(.red)
                                .clipShape(Capsule())
                        }
                        if let total = totalDisplay {
                            Text(total)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(gradeColor(course.total))
                        } else {
                            Text("--")
                                .font(.subheadline)
                                .foregroundStyle(ColorHelper.color(from: "#475569"))
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isOpen ? 90 : 0))
                            .animation(.easeInOut(duration: 0.2), value: isOpen)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            if isOpen {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 0) {
                        ScoreCell(label: "平時", value: course.regular, gradeColor: gradeColor, highlighted: false)
                        ScoreCell(label: "期中", value: course.midterm, gradeColor: gradeColor, highlighted: false)
                        ScoreCell(label: "期末", value: course.finalExam, gradeColor: gradeColor, highlighted: false)
                        ScoreCell(label: "總分", value: course.total, gradeColor: gradeColor, highlighted: true)
                    }

                    if let remark = course.remark,
                       !remark.trimmingCharacters(in: .whitespaces).isEmpty,
                       remark.trimmingCharacters(in: .whitespaces) != "@" {
                        Text(remark)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.bottom, 2)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - ScoreCell

private struct ScoreCell: View {
    let label: String
    let value: String?
    let gradeColor: (String?) -> Color
    let highlighted: Bool

    private var display: String {
        guard let v = value?.trimmingCharacters(in: .whitespaces), !v.isEmpty else { return "--" }
        return v.hasPrefix("*") ? String(v.dropFirst()) : v
    }

    private var isMuted: Bool {
        guard let v = value?.trimmingCharacters(in: .whitespaces), !v.isEmpty else { return true }
        let specialTerms = ["停修", "未開放", "未登錄", "修讀中", "尚無", "--"]
        if specialTerms.contains(where: { v.contains($0) }) { return true }
        let stripped = v.hasPrefix("*") ? String(v.dropFirst()) : v
        return Double(stripped) == nil
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(display)
                .font(highlighted ? .subheadline.weight(.bold) : .subheadline)
                .foregroundStyle(isMuted ? ColorHelper.color(from: "#475569") : gradeColor(value))

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .overlay(
            highlighted
                ? RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.indigo.opacity(0.4), lineWidth: 1.5)
                    .padding(.horizontal, 4)
                : nil
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        TranscriptView()
    }
    .environment(AuthViewModel())
}
#endif
