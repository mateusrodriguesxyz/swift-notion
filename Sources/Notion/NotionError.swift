import Foundation

/// Errors surfaced by the Notion client and generated page decoders.
public enum NotionError: Error, Equatable, Sendable, LocalizedError {
    /// An error response returned by the Notion API.
    case api(NotionAPIError)
    /// A page omitted a property declared by a `@NotionPage` model.
    case propertyNotFound(propertyName: String, availableProperties: [String])

    public var errorDescription: String? {
        switch self {
        case .api(let error):
            return error.message
        case .propertyNotFound(let propertyName, let availableProperties):
            return "NotionError.propertyNotFound: Property '\(propertyName)' not found in notion page properties (\(availableProperties.sorted().map { "'\($0)'" }.joined(separator: ", ")))."
        }
    }
}

extension NotionError: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .api(let error):
            return error.debugDescription
        case .propertyNotFound:
            return errorDescription!
        }
    }
}
