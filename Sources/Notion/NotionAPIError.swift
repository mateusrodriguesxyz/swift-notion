import Foundation

/// An error response returned by the Notion API.
///
/// https://developers.notion.com/reference/errors
public struct NotionAPIError: Error, Decodable, Equatable, Sendable {
    public let object: String
    public let status: Int
    public let code: String
    public let message: String
    public let requestID: String?

    enum CodingKeys: String, CodingKey {
        case object
        case status
        case code
        case message
        case requestID = "request_id"
    }
}

extension NotionAPIError: CustomDebugStringConvertible {
    public var debugDescription: String {
        message
    }
}

/// Returns `data` for a 2xx response; throws the decoded `NotionError.api` for
/// any other status.
func notionResponseData(_ data: Data, _ response: URLResponse) throws -> Data {
    guard let response = response as? HTTPURLResponse else {
        throw URLError(.badServerResponse)
    }

    guard (200..<300).contains(response.statusCode) else {
        let error = try JSONDecoder().decode(NotionAPIError.self, from: data)
        throw NotionError.api(error)
    }

    return data
}
