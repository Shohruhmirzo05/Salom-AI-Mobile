//
//  SupabaseAuthManager.swift
//  Salom-Ai-iOS
//
//  Created by Codex on 22/12/24.
//

import Foundation

struct SupabaseOAuthSession: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?
    let tokenType: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

struct SupabaseErrorResponse: Decodable {
    let error: String?
    let errorDescription: String?
    let msg: String?
}

enum SupabaseAuthError: LocalizedError {
    case missingConfig
    case invalidResponse
    case server(status: Int, message: String?)
    
    var errorDescription: String? {
        switch self {
        case .missingConfig:
            return "Supabase configuration is missing."
        case .invalidResponse:
            return "Invalid response from Supabase."
        case .server(let status, let message):
            return message ?? "Supabase request failed with status \(status)"
        }
    }
}

final class SupabaseAuthManager {
    static let shared = SupabaseAuthManager()
    
    private let supabaseURL: URL?
    private let supabaseKey: String?
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
    
    private init() {
        let info = Bundle.main.infoDictionary ?? [:]
        let env = ProcessInfo.processInfo.environment
        
        if let urlString = info["SUPABASE_URL"] as? String ?? env["SUPABASE_URL"],
           let url = URL(string: urlString) {
            self.supabaseURL = url
        } else {
            self.supabaseURL = nil
        }
        
        if let key = info["SUPABASE_ANON_KEY"] as? String ?? env["SUPABASE_ANON_KEY"] {
            self.supabaseKey = key
        } else {
            self.supabaseKey = nil
        }
    }
    
    func exchangeIdToken(_ idToken: String, provider: OAuthProvider) async throws -> SupabaseOAuthSession {
        guard let supabaseURL, let supabaseKey else {
            throw SupabaseAuthError.missingConfig
        }
        
        var components = URLComponents(url: supabaseURL, resolvingAgainstBaseURL: false)
        let basePath = supabaseURL.path == "/" ? "" : supabaseURL.path
        components?.path = basePath + "/auth/v1/token"
        components?.queryItems = [URLQueryItem(name: "grant_type", value: "id_token")]
        
        guard let url = components?.url else {
            throw SupabaseAuthError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "id_token": idToken,
            "provider": provider.supabaseValue,
            "platform": "ios"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: .fragmentsAllowed)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseAuthError.invalidResponse
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let message = decodeSupabaseError(from: data)
            throw SupabaseAuthError.server(status: httpResponse.statusCode, message: message)
        }
        
        return try decoder.decode(SupabaseOAuthSession.self, from: data)
    }
    
    private func decodeSupabaseError(from data: Data) -> String? {
        guard let decoded = try? decoder.decode(SupabaseErrorResponse.self, from: data) else {
            return String(data: data, encoding: .utf8)
        }
        
        return decoded.errorDescription ?? decoded.error ?? decoded.msg
    }
}
