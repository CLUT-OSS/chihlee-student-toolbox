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

// MARK: - iLife Leave Models

struct IlifeLeaveTypeOption: Decodable, Identifiable {
    let value: String
    let label: String
    let caption: String?

    var id: String { value }
}

struct IlifeLeaveSelected: Decodable {
    let sdate: String
    let edate: String
    let type: String?

    init(sdate: String, edate: String, type: String?) {
        self.sdate = sdate
        self.edate = edate
        self.type = type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sdate = try container.decodeIfPresent(String.self, forKey: .sdate) ?? ""
        edate = try container.decodeIfPresent(String.self, forKey: .edate) ?? sdate
        type = try container.decodeIfPresent(String.self, forKey: .type)
    }

    enum CodingKeys: String, CodingKey {
        case sdate
        case edate
        case type
    }
}

struct IlifeLeaveCoursePeriod: Decodable, Identifiable {
    let period: String
    let courseName: String
    let roomNo: String?
    let subjectID: String?

    var id: String { "\(period)-\(subjectID ?? courseName)" }

    enum CodingKeys: String, CodingKey {
        case period
        case courseName = "course_name"
        case roomNo = "room_no"
        case subjectID = "subject_id"
    }
}

struct IlifeLeaveCourseDay: Decodable, Identifiable {
    let displayDate: String
    let periods: [IlifeLeaveCoursePeriod]

    var id: String { displayDate + "-\(periods.count)" }

    enum CodingKeys: String, CodingKey {
        case displayDate = "display_date"
        case periods
    }
}

struct IlifeLeaveCoursesData: Decodable {
    let status: Bool
    let message: String?
    let days: [IlifeLeaveCourseDay]

    init(status: Bool, message: String?, days: [IlifeLeaveCourseDay]) {
        self.status = status
        self.message = message
        self.days = days
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decodeIfPresent(Bool.self, forKey: .status) ?? false
        message = try container.decodeIfPresent(String.self, forKey: .message)
        days = try container.decodeIfPresent([IlifeLeaveCourseDay].self, forKey: .days) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case status
        case message
        case days
    }
}

struct IlifeLeaveData: Decodable {
    let leaveTypes: [IlifeLeaveTypeOption]
    let selected: IlifeLeaveSelected
    let courses: IlifeLeaveCoursesData?

    init(leaveTypes: [IlifeLeaveTypeOption], selected: IlifeLeaveSelected, courses: IlifeLeaveCoursesData?) {
        self.leaveTypes = leaveTypes
        self.selected = selected
        self.courses = courses
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        leaveTypes = try container.decodeIfPresent([IlifeLeaveTypeOption].self, forKey: .leaveTypes) ?? []
        selected = try container.decodeIfPresent(IlifeLeaveSelected.self, forKey: .selected)
            ?? IlifeLeaveSelected(sdate: "", edate: "", type: nil)
        courses = try container.decodeIfPresent(IlifeLeaveCoursesData.self, forKey: .courses)
    }

    enum CodingKeys: String, CodingKey {
        case leaveTypes = "leave_types"
        case selected
        case courses
    }
}

struct IlifeLeaveSubmitResult: Decodable {
    let success: Bool
    let message: String
    let details: [String]
    let recordID: String?

    init(success: Bool, message: String, details: [String], recordID: String?) {
        self.success = success
        self.message = message
        self.details = details
        self.recordID = recordID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? false
        message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
        details = try container.decodeIfPresent([String].self, forKey: .details) ?? []
        recordID = try container.decodeLossyString(forKey: .recordID)
    }

    enum CodingKeys: String, CodingKey {
        case success
        case message
        case details
        case recordID = "record_id"
    }
}

struct IlifeCancelLeaveResult: Decodable {
    let success: Bool
    let message: String
    let details: [String]

    init(success: Bool, message: String, details: [String]) {
        self.success = success
        self.message = message
        self.details = details
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? false
        message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
        details = try container.decodeIfPresent([String].self, forKey: .details) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case success
        case message
        case details
    }
}

struct IlifeLeaveRecord: Decodable, Identifiable {
    let recordID: String
    let status: String?
    let submittedAt: String?
    let leaveType: String?
    let type: String?
    let sdate: String?
    let edate: String?
    let courseCount: Int?

    var id: String { recordID }

    enum CodingKeys: String, CodingKey {
        case recordID = "record_id"
        case id
        case status
        case submittedAt = "submitted_at"
        case leaveType = "leave_type"
        case type
        case sdate
        case edate
        case courseCount = "course_count"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let decoded = try container.decodeLossyString(forKey: .recordID) {
            recordID = decoded
        } else if let decoded = try container.decodeLossyString(forKey: .id) {
            recordID = decoded
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.recordID,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing record_id")
            )
        }
        status = try container.decodeIfPresent(String.self, forKey: .status)
        submittedAt = try container.decodeIfPresent(String.self, forKey: .submittedAt)
        leaveType = try container.decodeIfPresent(String.self, forKey: .leaveType)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        sdate = try container.decodeIfPresent(String.self, forKey: .sdate)
        edate = try container.decodeIfPresent(String.self, forKey: .edate)

        if let intValue = try container.decodeIfPresent(Int.self, forKey: .courseCount) {
            courseCount = intValue
        } else if let stringValue = try container.decodeIfPresent(String.self, forKey: .courseCount),
                  let intValue = Int(stringValue) {
            courseCount = intValue
        } else {
            courseCount = nil
        }
    }
}

struct IlifeLeaveRecordDetailEntry: Decodable, Identifiable {
    let date: String?
    let period: String?
    let subject: String?

    var id: String {
        "\(date ?? "")-\(period ?? "")-\(subject ?? "")"
    }
}

struct IlifeLeaveRecordDetail: Decodable {
    let recordID: String?
    let status: String?
    let leaveType: String?
    let type: String?
    let reason: String?
    let opinion: String?
    let sdate: String?
    let edate: String?
    let entries: [IlifeLeaveRecordDetailEntry]

    enum CodingKeys: String, CodingKey {
        case recordID = "record_id"
        case id
        case status
        case leaveType = "leave_type"
        case type
        case reason
        case opinion
        case sdate
        case edate
        case entries
    }

    init(recordID: String?, status: String?, leaveType: String?, type: String?, reason: String?, opinion: String?, sdate: String?, edate: String?, entries: [IlifeLeaveRecordDetailEntry]) {
        self.recordID = recordID
        self.status = status
        self.leaveType = leaveType
        self.type = type
        self.reason = reason
        self.opinion = opinion
        self.sdate = sdate
        self.edate = edate
        self.entries = entries
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recordID = try container.decodeLossyString(forKey: .recordID)
            ?? container.decodeLossyString(forKey: .id)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        leaveType = try container.decodeIfPresent(String.self, forKey: .leaveType)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        opinion = try container.decodeIfPresent(String.self, forKey: .opinion)
        sdate = try container.decodeIfPresent(String.self, forKey: .sdate)
        edate = try container.decodeIfPresent(String.self, forKey: .edate)
        entries = try container.decodeIfPresent([IlifeLeaveRecordDetailEntry].self, forKey: .entries) ?? []
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyString(forKey key: Key) throws -> String? {
        if let value = try decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let intValue = try decodeIfPresent(Int.self, forKey: key) {
            return String(intValue)
        }
        if let doubleValue = try decodeIfPresent(Double.self, forKey: key) {
            return String(doubleValue)
        }
        return nil
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

    private struct ApiErrorPayload: Decodable {
        let message: String?
    }

    struct IlifeLeaveSubmitCourse: Encodable {
        let courseID: String
        let date: String
        let period: String

        enum CodingKeys: String, CodingKey {
            case courseID = "course_id"
            case date
            case period
        }
    }

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

    static func fetchIlifeLeave(
        token: String,
        sdate: String,
        edate: String? = nil,
        type: String? = nil
    ) async throws -> IlifeLeaveData {
        var components = URLComponents(string: "\(baseURL)/api/v1/ilife/leave")!
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "sdate", value: sdate)]
        if let edate, !edate.isEmpty {
            queryItems.append(URLQueryItem(name: "edate", value: edate))
        }
        if let type, !type.isEmpty {
            queryItems.append(URLQueryItem(name: "type", value: type))
        }
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as! HTTPURLResponse
        guard http.statusCode == 200 else {
            throw AuthError.serverError("HTTP \(http.statusCode)")
        }

        struct Envelope: Decodable {
            let data: IlifeLeaveData?
            let error: ApiErrorPayload?
        }

        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        if let payload = envelope.data {
            return payload
        }
        if let message = envelope.error?.message, !message.isEmpty {
            throw AuthError.serverError(message)
        }
        return IlifeLeaveData(
            leaveTypes: [],
            selected: IlifeLeaveSelected(sdate: sdate, edate: edate ?? sdate, type: type),
            courses: nil
        )
    }

    static func submitIlifeLeave(
        token: String,
        type: String,
        sdate: String,
        edate: String,
        reason: String,
        leaves: [IlifeLeaveSubmitCourse]
    ) async throws -> IlifeLeaveSubmitResult {
        let url = URL(string: "\(baseURL)/api/v1/ilife/leave")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct Body: Encodable {
            let type: String
            let sdate: String
            let edate: String
            let reason: String
            let leaves: [IlifeLeaveSubmitCourse]
        }

        request.httpBody = try JSONEncoder().encode(Body(
            type: type,
            sdate: sdate,
            edate: edate,
            reason: reason,
            leaves: leaves
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as! HTTPURLResponse
        guard http.statusCode == 200 else {
            throw AuthError.serverError("HTTP \(http.statusCode)")
        }

        struct Envelope: Decodable {
            let data: IlifeLeaveSubmitResult?
            let error: ApiErrorPayload?
        }

        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        if let payload = envelope.data {
            return payload
        }
        if let message = envelope.error?.message, !message.isEmpty {
            return IlifeLeaveSubmitResult(success: false, message: message, details: [], recordID: nil)
        }
        return IlifeLeaveSubmitResult(success: false, message: "送出失敗", details: [], recordID: nil)
    }

    static func fetchIlifeLeaveRecords(token: String) async throws -> [IlifeLeaveRecord] {
        let url = URL(string: "\(baseURL)/api/v1/ilife/leave/record")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as! HTTPURLResponse
        guard http.statusCode == 200 else {
            throw AuthError.serverError("HTTP \(http.statusCode)")
        }

        struct Envelope: Decodable {
            let data: Payload?
            let error: ApiErrorPayload?
            struct Payload: Decodable {
                let records: LossyDecodableArray<IlifeLeaveRecord>?
            }
        }

        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        if let message = envelope.error?.message, !message.isEmpty {
            throw AuthError.serverError(message)
        }
        return envelope.data?.records?.elements ?? []
    }

    static func fetchIlifeLeaveRecordDetail(token: String, recordID: String) async throws -> IlifeLeaveRecordDetail {
        var components = URLComponents(string: "\(baseURL)/api/v1/ilife/leave/show_record")!
        components.queryItems = [URLQueryItem(name: "record_id", value: recordID)]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as! HTTPURLResponse
        guard http.statusCode == 200 else {
            throw AuthError.serverError("HTTP \(http.statusCode)")
        }

        struct Envelope: Decodable {
            let data: IlifeLeaveRecordDetail?
            let error: ApiErrorPayload?
        }

        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        if let payload = envelope.data {
            return payload
        }
        if let message = envelope.error?.message, !message.isEmpty {
            throw AuthError.serverError(message)
        }
        return IlifeLeaveRecordDetail(
            recordID: recordID,
            status: nil,
            leaveType: nil,
            type: nil,
            reason: nil,
            opinion: nil,
            sdate: nil,
            edate: nil,
            entries: []
        )
    }

    static func cancelIlifeLeave(token: String, recordID: String) async throws -> IlifeCancelLeaveResult {
        let url = URL(string: "\(baseURL)/api/v1/ilife/cancel_leave")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct Body: Encodable {
            let id: String
        }

        request.httpBody = try JSONEncoder().encode(Body(id: recordID))

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as! HTTPURLResponse
        guard http.statusCode == 200 else {
            throw AuthError.serverError("HTTP \(http.statusCode)")
        }

        struct Envelope: Decodable {
            let data: IlifeCancelLeaveResult?
            let error: ApiErrorPayload?
        }

        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        if let payload = envelope.data {
            return payload
        }
        if let message = envelope.error?.message, !message.isEmpty {
            return IlifeCancelLeaveResult(success: false, message: message, details: [])
        }
        return IlifeCancelLeaveResult(success: false, message: "取消失敗", details: [])
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
