//
//  APIService.swift
//  sklad
//

import Foundation
import UIKit

final class APIService {

    static let shared = APIService()

    var baseURL: String { "http://192.168.0.14:8000/api" }

    /// Полный URL для загрузки фото (медиа-файлы)
    func photoURL(for path: String?) -> URL? {
        guard let path = path, !path.isEmpty else { return nil }
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }
        let base = baseURL.replacingOccurrences(of: "/api", with: "")
        let mediaPath: String
        if path.hasPrefix("/") {
            mediaPath = path.hasPrefix("/media") ? path : "/media\(path)"
        } else {
            mediaPath = path.hasPrefix("media/") ? "/\(path)" : "/media/\(path)"
        }
        return URL(string: "\(base)\(mediaPath)")
    }

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: str) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(str)")
        }
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private init() {}

    private func addAuthHeaders(to req: inout URLRequest) {
        if let token = UserDefaults.standard.string(forKey: "auth_access_token") {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    func fetchItems() async throws -> [APIItem] {
        let data = try await get(path: "/items/")
        return try decoder.decode([APIItem].self, from: data)
    }

    func fetchItem(id: UUID) async throws -> APIItem {
        let data = try await get(path: "/items/\(id.uuidString.lowercased())/")
        return try decoder.decode(APIItem.self, from: data)
    }

    func createItem(name: String, photoData: Data?, itemDescription: String?) async throws -> APIItem {
        var req = URLRequest(url: URL(string: "\(baseURL)/items/")!)
        req.httpMethod = "POST"

        let boundary = UUID().uuidString
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"name\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(name)\r\n".data(using: .utf8)!)

        if let desc = itemDescription, !desc.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"item_description\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(desc)\r\n".data(using: .utf8)!)
        }

        if let data = photoData {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body
        addAuthHeaders(to: &req)

        let responseData = try await performRequest(req)
        return try decoder.decode(APIItem.self, from: responseData)
    }

    func updateItem(id: UUID, name: String?, photoData: Data?, itemDescription: String?) async throws -> APIItem {
        var req = URLRequest(url: URL(string: "\(baseURL)/items/\(id.uuidString.lowercased())/")!)
        req.httpMethod = "PATCH"

        if photoData != nil {
            let boundary = UUID().uuidString
            req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            var body = Data()
            if let n = name {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"name\"\r\n\r\n\(n)\r\n".data(using: .utf8)!)
            }
            if let desc = itemDescription {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"item_description\"\r\n\r\n\(desc)\r\n".data(using: .utf8)!)
            }
            if let data = photoData {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"photo.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
                body.append(data)
                body.append("\r\n".data(using: .utf8)!)
            }
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            req.httpBody = body
        } else {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            var dict: [String: String] = [:]
            if let n = name { dict["name"] = n }
            if let d = itemDescription { dict["item_description"] = d }
            req.httpBody = try encoder.encode(dict)
        }
        addAuthHeaders(to: &req)

        let responseData = try await performRequest(req)
        return try decoder.decode(APIItem.self, from: responseData)
    }

    func deleteItem(id: UUID) async throws {
        var req = URLRequest(url: URL(string: "\(baseURL)/items/\(id.uuidString.lowercased())/")!)
        req.httpMethod = "DELETE"
        addAuthHeaders(to: &req)
        _ = try await performRequest(req)
    }

    func createSize(itemId: UUID, sizeLabel: String, barcode: String?) async throws -> APISize {
        var req = URLRequest(url: URL(string: "\(baseURL)/items/\(itemId.uuidString.lowercased())/sizes/")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var dict: [String: Any] = ["size_label": sizeLabel]
        if let b = barcode, !b.isEmpty { dict["barcode"] = b }
        req.httpBody = try JSONSerialization.data(withJSONObject: dict)
        addAuthHeaders(to: &req)

        let data = try await performRequest(req)
        return try decoder.decode(APISize.self, from: data)
    }

    func updateSize(itemId: UUID, sizeId: UUID, sizeLabel: String, barcode: String?) async throws -> APISize {
        var req = URLRequest(url: URL(string: "\(baseURL)/items/\(itemId.uuidString.lowercased())/sizes/\(sizeId.uuidString.lowercased())/")!)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var dict: [String: Any] = ["size_label": sizeLabel]
        dict["barcode"] = barcode ?? ""
        req.httpBody = try JSONSerialization.data(withJSONObject: dict)
        addAuthHeaders(to: &req)

        let data = try await performRequest(req)
        return try decoder.decode(APISize.self, from: data)
    }

    func deleteSize(itemId: UUID, sizeId: UUID) async throws {
        var req = URLRequest(url: URL(string: "\(baseURL)/items/\(itemId.uuidString.lowercased())/sizes/\(sizeId.uuidString.lowercased())/")!)
        req.httpMethod = "DELETE"
        addAuthHeaders(to: &req)
        _ = try await performRequest(req)
    }

    func fetchSupplies(itemId: UUID? = nil) async throws -> [APISupply] {
        var path = "/supplies/"
        if let id = itemId {
            path += "?item_id=\(id.uuidString.lowercased())"
        }
        let data = try await get(path: path)
        return try decoder.decode([APISupply].self, from: data)
    }

    func fetchSupply(id: UUID) async throws -> APISupply {
        let data = try await get(path: "/supplies/\(id.uuidString.lowercased())/")
        return try decoder.decode(APISupply.self, from: data)
    }

    func createSupply(type: String, lines: [(itemId: UUID, sizeLabel: String, quantity: Int)]) async throws -> APISupply {
        let payload = SupplyCreatePayload(
            type: type,
            lines: lines.map { SupplyLinePayload(itemId: $0.itemId, sizeLabel: $0.sizeLabel, quantity: $0.quantity) }
        )
        var req = URLRequest(url: URL(string: "\(baseURL)/supplies/")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(payload)
        addAuthHeaders(to: &req)

        let data = try await performRequest(req)
        return try decoder.decode(APISupply.self, from: data)
    }

    func findByBarcode(_ barcode: String) async throws -> (itemId: UUID, sizeLabel: String) {
        let path = "/sizes/by_barcode/?barcode=\(barcode.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? barcode)"
        let data = try await get(path: path)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let itemIdStr = json?["item_id"] as? String,
              let itemId = UUID(uuidString: itemIdStr),
              let sizeLabel = json?["size_label"] as? String else {
            throw APIError.serverError("Штрихкод не найден")
        }
        return (itemId, sizeLabel)
    }

    func loadImage(urlString: String) async -> UIImage? {
        let base = baseURL.replacingOccurrences(of: "/api", with: "")
        let path = urlString.hasPrefix("/") ? urlString : "/media/\(urlString)"
        guard let url = URL(string: urlString.hasPrefix("http") ? urlString : "\(base)\(path)") else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: data)
    }

    private func get(path: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        addAuthHeaders(to: &req)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.serverError(parseErrorMessage(from: data, statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0))
        }
        return data
    }

    private func performRequest(_ req: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.serverError("Нет ответа от сервера")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.serverError(parseErrorMessage(from: data, statusCode: http.statusCode))
        }
        return data
    }

    private func parseErrorMessage(from data: Data, statusCode: Int = 0) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let detail = json["detail"] as? String, !detail.isEmpty { return detail }
            if let errors = json as? [String: [String]], let first = errors.values.first, let msg = first.first {
                return msg
            }
            for (_, val) in json {
                if let arr = val as? [String], let msg = arr.first { return msg }
                if let msg = val as? String { return msg }
            }
        }
        if let raw = String(data: data, encoding: .utf8), raw.contains("<!DOCTYPE") {
            return "Ошибка сервера (\(statusCode)). Проверьте логи Django."
        }
        return "Ошибка сервера (\(statusCode))"
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Неверный URL"
        case .serverError(let msg): return msg.isEmpty ? "Ошибка сервера" : msg
        }
    }
}
