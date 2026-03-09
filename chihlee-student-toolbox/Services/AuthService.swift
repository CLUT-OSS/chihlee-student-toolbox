import Foundation

enum AuthError: LocalizedError {
    case invalidCredentials
    case tooManyRequests
    case serverError(String)
    case networkError(String)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: "帳號或密碼錯誤"
        case .tooManyRequests: "請求過於頻繁，請稍後再試"
        case .serverError(let msg): "伺服器錯誤：\(msg)"
        case .networkError(let msg): "網路錯誤：\(msg)"
        case .decodingError: "回應格式錯誤"
        }
    }
}

// MARK: - Response Models

private struct ApiEnvelope<T: Decodable>: Decodable {
    let status: String
    let data: T?
    let error: ApiErrorBody?
}

private struct ApiErrorBody: Decodable {
    let code: String
    let message: String
}

struct LoginResponseData: Decodable {
    let wrapperToken: String
    let dlcConnected: Bool
    let eportfolioConnected: Bool
    let ilifeConnected: Bool

    enum CodingKeys: String, CodingKey {
        case wrapperToken = "wrapper_token"
        case dlcConnected = "dlc_connected"
        case eportfolioConnected = "eportfolio_connected"
        case ilifeConnected = "ilife_connected"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        wrapperToken = try container.decode(String.self, forKey: .wrapperToken)
        dlcConnected = try container.decodeIfPresent(Bool.self, forKey: .dlcConnected) ?? false
        eportfolioConnected = try container.decodeIfPresent(Bool.self, forKey: .eportfolioConnected) ?? false
        ilifeConnected = try container.decodeIfPresent(Bool.self, forKey: .ilifeConnected) ?? false
    }
}

struct SessionStatusData: Decodable {
    let wrapperToken: String?
    let createdAt: String?
    let lastSeenAt: String?
    let expiresAt: String?
    let dlcConnected: Bool
    let eportfolioConnected: Bool
    let ilifeConnected: Bool
    let studentIDHash: String?

    enum CodingKeys: String, CodingKey {
        case wrapperToken = "wrapper_token"
        case createdAt = "created_at"
        case lastSeenAt = "last_seen_at"
        case expiresAt = "expires_at"
        case dlcConnected = "dlc_connected"
        case eportfolioConnected = "eportfolio_connected"
        case ilifeConnected = "ilife_connected"
        case studentIDHash = "student_id_hash"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        wrapperToken = try container.decodeIfPresent(String.self, forKey: .wrapperToken)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        lastSeenAt = try container.decodeIfPresent(String.self, forKey: .lastSeenAt)
        expiresAt = try container.decodeIfPresent(String.self, forKey: .expiresAt)
        dlcConnected = try container.decodeIfPresent(Bool.self, forKey: .dlcConnected) ?? false
        eportfolioConnected = try container.decodeIfPresent(Bool.self, forKey: .eportfolioConnected) ?? false
        ilifeConnected = try container.decodeIfPresent(Bool.self, forKey: .ilifeConnected) ?? false
        studentIDHash = try container.decodeIfPresent(String.self, forKey: .studentIDHash)
    }
}

// MARK: - Service

struct AuthService {
    static let baseURL = "https://chihlee-api.c-h.tw"

    static func login(muid: String, mpassword: String) async throws -> LoginResponseData {
        let url = URL(string: "\(baseURL)/api/v1/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["muid": muid, "mpassword": mpassword])

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as! HTTPURLResponse

        switch http.statusCode {
        case 200:
            let envelope = try JSONDecoder().decode(ApiEnvelope<LoginResponseData>.self, from: data)
            guard let loginData = envelope.data else { throw AuthError.decodingError }
            return loginData
        case 401:
            throw AuthError.invalidCredentials
        case 429:
            throw AuthError.tooManyRequests
        default:
            let envelope = try? JSONDecoder().decode(ApiEnvelope<EmptyData>.self, from: data)
            throw AuthError.serverError(envelope?.error?.message ?? "HTTP \(http.statusCode)")
        }
    }

    static func logout(token: String) async throws {
        let url = URL(string: "\(baseURL)/api/v1/auth/logout")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        let http = response as! HTTPURLResponse
        guard http.statusCode == 200 else { return }
    }

    static func checkSession(token: String) async throws -> SessionStatusData {
        let url = URL(string: "\(baseURL)/api/v1/auth/session")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as! HTTPURLResponse

        switch http.statusCode {
        case 200:
            let envelope = try JSONDecoder().decode(ApiEnvelope<SessionStatusData>.self, from: data)
            guard let sessionData = envelope.data else { throw AuthError.decodingError }
            return sessionData
        case 401:
            throw AuthError.invalidCredentials
        case 429:
            throw AuthError.tooManyRequests
        default:
            throw AuthError.serverError("HTTP \(http.statusCode)")
        }
    }
}

private struct EmptyData: Decodable {}
