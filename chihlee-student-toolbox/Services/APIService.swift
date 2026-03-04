import Foundation

// MARK: - Schedule Models

struct APIScheduleClass: Decodable {
    let name: String
    let classroom: String?
    let teacher: String?
    let syllabusUrl: String?

    enum CodingKeys: String, CodingKey {
        case name, classroom, teacher
        case syllabusUrl = "syllabus_url"
    }
}

struct APIScheduleSlot: Decodable {
    let period: String
    let weekday: String
    let classes: [APIScheduleClass]
}

struct APIScheduleData: Decodable {
    let studentID: String
    let semester: String
    let semesterTitle: String
    let noTimeCourses: [String]
    let slots: [APIScheduleSlot]

    enum CodingKeys: String, CodingKey {
        case studentID
        case semester
        case semesterTitle = "semester_title"
        case noTimeCourses = "no_time_courses"
        case slots
    }
}

// MARK: - iLife Attendance Models

struct IlifeAttendanceRecord: Decodable, Identifiable {
    let date: String
    let period: String
    let status: String
    let courseTitle: String?

    var id: String { date + period + (courseTitle ?? "") }

    enum CodingKeys: String, CodingKey {
        case date
        case period
        case status
        case courseTitle = "course_title"
    }
}

// MARK: - DLC Calendar Models

struct DlcCalendarEvent: Decodable, Identifiable {
    let id: String
    let action: String?
    let assignmentName: String?
    let classCode: String?
    let courseName: String?
    let rawSubject: String?
    let semester: String?
    let type: String
    let dateString: String
    let timeBegin: String?
    let timeEnd: String?
    let subject: String
    let content: String
    let sourceTag: String

    private static let dateFormatters: [DateFormatter] = {
        let shortDate = DateFormatter()
        shortDate.dateFormat = "yyyy-MM-dd"
        shortDate.locale = Locale(identifier: "en_US_POSIX")

        let fullDateTime = DateFormatter()
        fullDateTime.dateFormat = "yyyy-MM-dd HH:mm:ss"
        fullDateTime.locale = Locale(identifier: "en_US_POSIX")

        return [shortDate, fullDateTime]
    }()
    private static let iso8601Formatter = ISO8601DateFormatter()
    private static let rangeSeparators = ["~", "～", "－", "–", "—", "-"]

    private struct ParsedDateRange {
        let start: Date
        let end: Date?
    }

    var date: Date? {
        Self.parsedDateRange(from: dateString)?.start
    }

    var endDate: Date? {
        Self.parsedDateRange(from: dateString)?.end
    }

    var displaySubject: String {
        let compact = subject
            .replacingOccurrences(of: "（暫定）", with: "")
            .replacingOccurrences(of: "(暫定)", with: "")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let firstClause = compact
            .components(separatedBy: CharacterSet(charactersIn: "；;"))
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? compact
        return firstClause
    }

    func occurs(on day: Date) -> Bool {
        guard let startDate = date else { return false }
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: day)
        let startDay = calendar.startOfDay(for: startDate)

        if let endDate {
            let endDay = calendar.startOfDay(for: endDate)
            return targetDay >= startDay && targetDay <= endDay
        }
        return calendar.isDate(targetDay, inSameDayAs: startDay)
    }

    private static func parsedDateRange(from rawDate: String) -> ParsedDateRange? {
        let raw = rawDate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        if let direct = parseKnownDate(raw) {
            return ParsedDateRange(start: direct, end: nil)
        }

        let cleaned = sanitizeDateText(raw)
        guard !cleaned.isEmpty else { return nil }

        if let direct = parseKnownDate(cleaned) {
            return ParsedDateRange(start: direct, end: nil)
        }

        for separator in rangeSeparators {
            let parts = cleaned.components(separatedBy: separator).filter { !$0.isEmpty }
            guard parts.count == 2 else { continue }
            guard let start = parseMonthDay(parts[0]),
                  let end = parseMonthDay(parts[1])
            else { continue }

            if start <= end {
                return ParsedDateRange(start: start, end: end)
            }
            return ParsedDateRange(start: end, end: start)
        }

        if let single = parseMonthDay(cleaned) {
            return ParsedDateRange(start: single, end: nil)
        }
        return nil
    }

    private static func sanitizeDateText(_ raw: String) -> String {
        let normalized = raw.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? raw
        let compact = normalized
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let fullDate = compact.range(
            of: #"\d{4}[-/]\d{1,2}[-/]\d{1,2}"#,
            options: .regularExpression
        ) {
            return String(compact[fullDate]).replacingOccurrences(of: "/", with: "-")
        }

        if let range = compact.range(
            of: #"\d{1,2}/\d{1,2}[~～－–—-]\d{1,2}/\d{1,2}"#,
            options: .regularExpression
        ) {
            return String(compact[range])
        }
        if let single = compact.range(of: #"\d{1,2}/\d{1,2}"#, options: .regularExpression) {
            return String(compact[single])
        }
        return ""
    }

    private static func parseKnownDate(_ raw: String) -> Date? {
        for formatter in Self.dateFormatters {
            if let parsed = formatter.date(from: raw) {
                return parsed
            }
        }
        if let parsed = Self.iso8601Formatter.date(from: raw) {
            return parsed
        }
        if raw.count >= 10 {
            let datePrefix = String(raw.prefix(10))
            for formatter in Self.dateFormatters {
                if let parsed = formatter.date(from: datePrefix) {
                    return parsed
                }
            }
        }
        return nil
    }

    private static func parseMonthDay(_ raw: String) -> Date? {
        if let direct = parseKnownDate(raw) {
            return direct
        }

        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = token.split(separator: "/", maxSplits: 1).map(String.init)
        let isDigits: (String) -> Bool = { part in
            !part.isEmpty && part.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
        }
        guard parts.count == 2,
              isDigits(parts[0]),
              isDigits(parts[1]),
              let month = Int(parts[0]),
              let day = Int(parts[1]),
              (1 ... 12).contains(month),
              (1 ... 31).contains(day)
        else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        let academicStartYear = currentMonth >= 8 ? currentYear : currentYear - 1
        let year = month >= 8 ? academicStartYear : academicStartYear + 1

        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    /// Deadline time string, shown when it's a specific time (not midnight / end-of-day)
    var deadlineTime: String? {
        guard let t = timeEnd, t != "00:00:00", t != "23:59:00" else { return nil }
        return String(t.prefix(5)) // "HH:mm"
    }

    init(schoolDateText: String, schoolEventTitle: String) {
        let cleanedDate = schoolDateText.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedTitle = schoolEventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        id = "school-\(cleanedDate)-\(cleanedTitle)".replacingOccurrences(of: " ", with: "")
        action = nil
        assignmentName = cleanedTitle
        classCode = nil
        courseName = nil
        rawSubject = cleanedTitle
        semester = nil
        type = "school_calendar"
        dateString = cleanedDate
        timeBegin = "00:00:00"
        timeEnd = "00:00:00"
        subject = cleanedTitle.isEmpty ? "未命名事件" : cleanedTitle
        content = cleanedTitle
        sourceTag = "學校行事曆"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedID = try container.decodeIfPresent(String.self, forKey: .id)
        let legacyID = try container.decodeIfPresent(String.self, forKey: .idx)
        id = decodedID ?? legacyID ?? UUID().uuidString
        action = try container.decodeIfPresent(String.self, forKey: .action)
        assignmentName = try container.decodeIfPresent(String.self, forKey: .assignmentName)
        classCode = try container.decodeIfPresent(String.self, forKey: .classCode)
        courseName = try container.decodeIfPresent(String.self, forKey: .courseName)
        rawSubject = try container.decodeIfPresent(String.self, forKey: .rawSubject)
        semester = try container.decodeIfPresent(String.self, forKey: .semester)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        let newDate = try container.decodeIfPresent(String.self, forKey: .date)
        let legacyDate = try container.decodeIfPresent(String.self, forKey: .memoDate)
        dateString = newDate ?? legacyDate ?? ""
        let newTimeBegin = try container.decodeIfPresent(String.self, forKey: .timeBegin)
        let legacyTimeBegin = try container.decodeIfPresent(String.self, forKey: .legacyTimeBegin)
        timeBegin = newTimeBegin ?? legacyTimeBegin
        let newTimeEnd = try container.decodeIfPresent(String.self, forKey: .timeEnd)
        let legacyTimeEnd = try container.decodeIfPresent(String.self, forKey: .legacyTimeEnd)
        timeEnd = newTimeEnd ?? legacyTimeEnd

        let legacySubject = try container.decodeIfPresent(String.self, forKey: .subject)
        subject = Self.firstNonEmpty([
            assignmentName,
            rawSubject,
            legacySubject,
            courseName,
            content,
        ]) ?? "未命名事件"
        let decodedSourceTag = try container
            .decodeIfPresent(String.self, forKey: .sourceTag)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let decodedSourceTag, !decodedSourceTag.isEmpty {
            sourceTag = decodedSourceTag
        } else {
            sourceTag = "數位學院行事曆"
        }
    }

    private static func firstNonEmpty(_ values: [String?]) -> String? {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    enum CodingKeys: String, CodingKey {
        case action
        case assignmentName
        case classCode
        case content
        case courseName
        case date
        case id
        case rawSubject
        case semester
        case timeBegin
        case timeEnd
        case type
        case idx
        case memoDate = "memo_date"
        case legacyTimeBegin = "time_begin"
        case legacyTimeEnd = "time_end"
        case subject
        case sourceTag = "source_tag"
    }
}

// MARK: - DLC Profile Model

struct DlcProfile: Decodable {
    let account: String?
    let name: String?
    let email: String?
}

struct LossyDecodableArray<Element: Decodable>: Decodable {
    let elements: [Element]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var decodedElements: [Element] = []

        while !container.isAtEnd {
            if let value = try? container.decode(LossyDecodableValue<Element>.self).value {
                decodedElements.append(value)
            } else {
                _ = try? container.decode(IgnoredDecodableValue.self)
            }
        }

        elements = decodedElements
    }
}

private struct LossyDecodableValue<Element: Decodable>: Decodable {
    let value: Element

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(Element.self)
    }
}

private struct IgnoredDecodableValue: Decodable {}

// MARK: - Scores Models

struct APISemesterScore: Decodable {
    let studentID: String
    let semester: String
    let semesterTitle: String
    let courses: [APICourseScore]
    let summary: APIScoreSummary?

    enum CodingKeys: String, CodingKey {
        case studentID
        case semester
        case semesterTitle = "semester_title"
        case courses
        case summary
    }
}

struct APICourseScore: Decodable {
    let name: String
    let teacher: String?
    let category: String?
    let credits: Double?
    let regular: String?
    let midterm: String?
    let finalExam: String?
    let total: String?
    let remark: String?

    enum CodingKeys: String, CodingKey {
        case name, teacher, category, credits
        case regular, midterm
        case finalExam = "final_exam"
        case total, remark
    }
}

struct APIScoreSummary: Decodable {
    let semesterAvg: String?
    let regularAvg: String?
    let midtermAvg: String?
    let creditsTaken: String?
    let creditsEarned: String?
    let conductScore: String?

    enum CodingKeys: String, CodingKey {
        case semesterAvg   = "semester_avg"
        case regularAvg    = "regular_avg"
        case midtermAvg    = "midterm_avg"
        case creditsTaken  = "credits_taken"
        case creditsEarned = "credits_earned"
        case conductScore  = "conduct_score"
    }
}

// MARK: - Service

struct APIService {
    static let baseURL = AuthService.baseURL
    static let schoolCalendarCSVURL = URL(string: "https://chihlee-cal-worker.thisisch.workers.dev/api/v1/csv")!

    static func fetchSchedule(token: String, semester: String? = nil) async throws -> [APIScheduleData] {
        var components = URLComponents(string: "\(baseURL)/api/v1/eportfolio/schedule")!
        if let semester, !semester.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            components.queryItems = [URLQueryItem(name: "semester", value: semester)]
        }
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .cancelled:
                throw CancellationError()
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .timedOut:
                throw AuthError.networkError("無法連線到伺服器 \(baseURL)，請確認手機與伺服器在同一網路")
            default:
                throw AuthError.networkError(error.localizedDescription)
            }
        } catch {
            throw AuthError.networkError(error.localizedDescription)
        }
        let http = response as! HTTPURLResponse

        guard http.statusCode == 200 else {
            throw AuthError.serverError("HTTP \(http.statusCode)")
        }

        struct Envelope: Decodable {
            let data: Payload?
            struct Payload: Decodable {
                let schedules: [APIScheduleData]
            }
        }

        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        return envelope.data?.schedules ?? []
    }

    static func fetchDlcCalendar(token: String, start: String, end: String) async throws -> [DlcCalendarEvent] {
        var comps = URLComponents(string: "\(baseURL)/api/v1/dlc/calendar")!
        comps.queryItems = [
            URLQueryItem(name: "start", value: start),
            URLQueryItem(name: "end", value: end),
        ]
        var request = URLRequest(url: comps.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as! HTTPURLResponse

        guard http.statusCode == 200 else {
            throw AuthError.serverError("HTTP \(http.statusCode)")
        }

        struct Envelope: Decodable {
            let data: Payload?
            struct Payload: Decodable {
                let events: LossyDecodableArray<DlcCalendarEvent>?
            }
        }

        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        return envelope.data?.events?.elements ?? []
    }

    static func fetchSchoolCalendarEvents() async throws -> [DlcCalendarEvent] {
        var request = URLRequest(url: schoolCalendarCSVURL)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as! HTTPURLResponse
        guard http.statusCode == 200 else {
            throw AuthError.serverError("HTTP \(http.statusCode)")
        }

        guard let csvText = String(data: data, encoding: .utf8) else {
            throw AuthError.decodingError
        }

        let rows = parseCSVRows(csvText)
        guard !rows.isEmpty else { return [] }

        let bodyRows: [[String]]
        if let first = rows.first,
           first.count >= 2,
           first[0].lowercased().contains("date"),
           first[1].lowercased().contains("event") {
            bodyRows = Array(rows.dropFirst())
        } else {
            bodyRows = rows
        }

        return bodyRows.compactMap { columns in
            guard columns.count >= 2 else { return nil }
            let date = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let event = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !date.isEmpty, !event.isEmpty else { return nil }
            return DlcCalendarEvent(schoolDateText: date, schoolEventTitle: event)
        }
    }

    static func fetchDlcProfile(token: String) async throws -> DlcProfile {
        let url = URL(string: "\(baseURL)/api/v1/dlc/profile")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as! HTTPURLResponse

        guard http.statusCode == 200 else {
            throw AuthError.serverError("HTTP \(http.statusCode)")
        }

        struct Envelope: Decodable {
            let data: DlcProfile?
        }

        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard let profile = envelope.data else { throw AuthError.decodingError }
        return profile
    }

    static func fetchScores(token: String) async throws -> [APISemesterScore] {
        let url = URL(string: "\(baseURL)/api/v1/eportfolio/scores")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as! HTTPURLResponse
        guard http.statusCode == 200 else {
            throw AuthError.serverError("HTTP \(http.statusCode)")
        }

        struct Envelope: Decodable {
            let data: Payload?
            struct Payload: Decodable {
                let scores: [APISemesterScore]
            }
        }

        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        return envelope.data?.scores ?? []
    }

    static func fetchIlifeAttendance(token: String) async throws -> [IlifeAttendanceRecord] {
        let url = URL(string: "\(baseURL)/api/v1/ilife/attendance")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as! HTTPURLResponse

        guard http.statusCode == 200 else {
            throw AuthError.serverError("HTTP \(http.statusCode)")
        }

        struct Envelope: Decodable {
            let data: Payload?
            struct Payload: Decodable {
                let records: [IlifeAttendanceRecord]
            }
        }

        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        return envelope.data?.records ?? []
    }

    private static func parseCSVRows(_ text: String) -> [[String]] {
        let normalizedText = text.replacingOccurrences(of: "\u{feff}", with: "")
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        let chars = Array(normalizedText)
        var index = 0

        while index < chars.count {
            let char = chars[index]

            if inQuotes {
                if char == "\"" {
                    let nextIndex = index + 1
                    if nextIndex < chars.count, chars[nextIndex] == "\"" {
                        field.append("\"")
                        index += 2
                        continue
                    }
                    inQuotes = false
                    index += 1
                    continue
                }
                field.append(char)
                index += 1
                continue
            }

            switch char {
            case "\"":
                inQuotes = true
            case ",":
                row.append(field)
                field = ""
            case "\n":
                row.append(field)
                field = ""
                if !row.allSatisfy(\.isEmpty) {
                    rows.append(row)
                }
                row = []
            case "\r":
                break
            default:
                field.append(char)
            }
            index += 1
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            if !row.allSatisfy(\.isEmpty) {
                rows.append(row)
            }
        }

        return rows
    }
}
