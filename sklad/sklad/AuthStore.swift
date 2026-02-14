//
//  AuthStore.swift
//  sklad
//

import Foundation
import Observation

struct APIWorkshop: Identifiable, Codable {
    let id: UUID
    var name: String
}

struct LoginResponse: Codable {
    let access: String
    let refresh: String
    let user: UserInfo
    let workshop: APIWorkshop?
}

struct UserInfo: Codable {
    let id: Int
    let username: String
}

@Observable
final class AuthStore {
    var accessToken: String? {
        didSet { UserDefaults.standard.set(accessToken, forKey: "auth_access_token") }
    }
    var refreshToken: String? {
        didSet { UserDefaults.standard.set(refreshToken, forKey: "auth_refresh_token") }
    }
    var currentUser: UserInfo?
    var workshop: APIWorkshop?

    var isAuthenticated: Bool { accessToken != nil }

    init() {
        accessToken = UserDefaults.standard.string(forKey: "auth_access_token")
        refreshToken = UserDefaults.standard.string(forKey: "auth_refresh_token")
    }

    func login(username: String, password: String) async throws {
        let url = URL(string: "\(APIService.shared.baseURL)/auth/login/")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["username": username, "password": password])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw AuthError.unknown }
        guard http.statusCode == 200 else {
            if let err = try? JSONDecoder().decode([String: String].self, from: data),
               let detail = err["detail"] { throw AuthError.server(detail) }
            throw AuthError.server("Ошибка входа")
        }
        let resp = try JSONDecoder().decode(LoginResponse.self, from: data)
        await MainActor.run {
            accessToken = resp.access
            refreshToken = resp.refresh
            currentUser = resp.user
            workshop = resp.workshop
        }
    }

    func logout() {
        accessToken = nil
        refreshToken = nil
        currentUser = nil
        workshop = nil
    }
}

enum AuthError: LocalizedError {
    case unknown
    case server(String)
    var errorDescription: String? {
        switch self {
        case .unknown: return "Неизвестная ошибка"
        case .server(let msg): return msg
        }
    }
}
