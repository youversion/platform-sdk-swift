import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension YouVersionAPI {
    /// Performs an SDK request with debug-only diagnostics, preserving responses and thrown errors.
    static func response(for request: URLRequest, session: URLSession) async throws -> (Data, URLResponse) {
        YouVersionPlatformLogger.debug("Sending \(APIRequestDiagnostics.requestSummary(request))", category: "API")
        do {
            let (data, response) = try await session.data(for: request)
            YouVersionPlatformLogger.debug(APIRequestDiagnostics.responseSummary(request, data: data, response: response), category: "API")
            return (data, response)
        } catch {
            YouVersionPlatformLogger.debug("Failed \(APIRequestDiagnostics.requestSummary(request)): \(APIRequestDiagnostics.errorSummary(error))", category: "API")
            throw error
        }
    }
}

struct APIRequestDiagnostics {
    /// Identifies the request without exposing credentials in its URL or headers.
    static func requestSummary(_ request: URLRequest) -> String {
        var components = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        components?.user = nil
        components?.password = nil
        components?.fragment = nil
        let queryItems = components?.queryItems?.map { item in
            URLQueryItem(name: item.name, value: isSensitive(item.name) || item.name == "code" ? "[redacted]" : item.value)
        }
        components?.queryItems = queryItems
        let endpoint = components?.url?.absoluteString ?? "<invalid URL>"
        var summary = "\(request.httpMethod ?? "GET") \(endpoint)"
        if let body = request.httpBody,
           let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
           let requestID = object["request_id"] as? String, UUID(uuidString: requestID) != nil {
            summary += " request_id=\(requestID)"
        }
        if let authorization = request.value(forHTTPHeaderField: "Authorization") {
            let parts = authorization.split(separator: " ", maxSplits: 1)
            if parts.count == 2 && parts[0].lowercased() == "bearer" {
                summary += " \(YouVersionAPI.Users.tokenScopeSummary(String(parts[1])))"
            }
        }
        return summary
    }

    /// Includes redacted error bodies and correlation IDs, but never successful response bodies.
    static func responseSummary(_ request: URLRequest, data: Data, response: URLResponse) -> String {
        let summary = requestSummary(request)
        guard let response = response as? HTTPURLResponse else {
            return "Received non-HTTP response for \(summary): \(type(of: response))"
        }
        var message = "Received HTTP \(response.statusCode) for \(summary) (\(data.count) bytes)"
        for field in ["content-type", "x-request-id", "x-correlation-id", "x-cloud-trace-context", "traceparent"] {
            if let value = response.value(forHTTPHeaderField: field) {
                message += " \(field)=\(value)"
            }
        }
        if !(200..<300).contains(response.statusCode) {
            let secrets = (request.allHTTPHeaderFields ?? [:]).filter { isSensitive($0.key) }.values.flatMap { value in
                let parts = value.split(separator: " ", maxSplits: 1)
                return parts.count == 2 && ["bearer", "basic"].contains(parts[0].lowercased()) ? [value, String(parts[1])] : [value]
            } + (request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?.queryItems ?? [])
                .filter { isSensitive($0.name) || $0.name == "code" }.compactMap(\.value) + (request.httpBody.map(bodyCredentials) ?? [])
            let body: String
            if data.isEmpty {
                body = "<empty>"
            } else if let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
                      let redacted = try? JSONSerialization.data(
                        withJSONObject: redacted(object, secrets: secrets.filter { !$0.isEmpty }),
                        options: [.fragmentsAllowed, .sortedKeys]
                      ) {
                body = String(bytes: redacted, encoding: .utf8) ?? "<invalid UTF-8>"
            } else {
                body = "<non-JSON error body omitted>"
            }
            message += " body=\(body.prefix(4096))\(body.count > 4096 ? "… [truncated]" : "")"
        }
        return message
    }

    /// Describes failure kinds and decoding paths without dumping NSError userInfo or note values.
    static func errorSummary(_ error: any Error) -> String {
        switch error {
        case let error as YouVersionAPIError:
            return String(describing: error)
        case let error as YouVersionAPIRequestError:
            return error.code.rawValue
        case DecodingError.keyNotFound(let key, let context):
            return "DecodingError: missing \(key.stringValue) at \(path(context))"
        case DecodingError.typeMismatch(let type, let context):
            return "DecodingError: expected \(type) at \(path(context))"
        case DecodingError.valueNotFound(let type, let context):
            return "DecodingError: missing \(type) value at \(path(context))"
        case DecodingError.dataCorrupted(let context):
            return "DecodingError: invalid data at \(path(context))"
        case let error as URLError:
            return "URLError \(error.code.rawValue): \(URLError(error.code).localizedDescription)"
        default:
            let error = error as NSError
            return "\(error.domain) code=\(error.code)"
        }
    }

    private static func path(_ context: DecodingError.Context) -> String {
        context.codingPath.isEmpty ? "$" : "$." + context.codingPath.map(\.stringValue).joined(separator: ".")
    }

    // Error payloads can echo private request fields; these names are deliberately redacted conservatively.
    private static func isSensitive(_ name: String) -> Bool {
        let name = name.lowercased().replacingOccurrences(of: "-", with: "_")
        return name.contains("token") || name.contains("key") || name.contains("authorization") || name.contains("secret") ||
            ["password", "client_secret", "code_verifier", "content", "title", "tags", "input"].contains(name)
    }

    private static func bodyCredentials(_ data: Data) -> [String] {
        let fields: [URLQueryItem]
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            fields = object.compactMap { key, value in
                (value as? String).map { URLQueryItem(name: key, value: $0) }
            }
        } else if let form = String(bytes: data, encoding: .utf8) {
            fields = URLComponents(string: "?" + form)?.queryItems ?? []
        } else {
            return []
        }
        return fields.filter {
            (isSensitive($0.name) || $0.name == "code") && !["content", "title", "tags", "input"].contains($0.name.lowercased())
        }.compactMap(\.value)
    }

    private static func redacted(_ value: Any, secrets: [String]) -> Any {
        if let object = value as? [String: Any] {
            return object.reduce(into: [String: Any]()) { result, field in
                result[field.key] = isSensitive(field.key) ? "[redacted]" : redacted(field.value, secrets: secrets)
            }
        }
        if let values = value as? [Any] {
            return values.map { redacted($0, secrets: secrets) }
        }
        if let text = value as? String {
            return secrets.reduce(text) { result, secret in
                if secret.count >= 8 {
                    return result.replacingOccurrences(of: secret, with: "[redacted]")
                }
                let pattern = "(?<![\\p{L}\\p{N}_])" + NSRegularExpression.escapedPattern(for: secret) + "(?![\\p{L}\\p{N}_])"
                return result.replacingOccurrences(of: pattern, with: "[redacted]", options: .regularExpression)
            }
        }
        return value
    }
}
