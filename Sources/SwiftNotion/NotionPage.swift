import Foundation

/// The Notion property backing one `@Notion*`-annotated stored property:
/// its Notion field name and the Notion property kind.
public struct NotionField: Sendable, Equatable {
    public let name: String
    public let kind: Kind

    public enum Kind: Sendable, Equatable {
        case title
        case richText
        case file
        case files
        case date
        case dateRange
        case relation
        case checkbox
        case number
    }

    public init(name: String, kind: Kind) {
        self.name = name
        self.kind = kind
    }
}

/// A type decoded from a Notion page by the `@NotionPage` macro.
public protocol NotionPage: Decodable {
    /// Maps each `@Notion*`-annotated property's key path to its Notion field.
    /// Synthesized by `@NotionPage`.
    static var notionProperties: [PartialKeyPath<Self>: NotionField] { get }
    
    /// Fetches related pages for all `@NotionRelationQuery` properties.
    /// Default implementation does nothing (for types without relation queries).
    mutating func _fetchRelations(using client: NotionClient) async throws
}

public extension NotionPage {
    /// The Notion field name registered for `keyPath`, or `nil`.
    static func notionField(for keyPath: PartialKeyPath<Self>) -> String? {
        notionProperties[keyPath]?.name
    }

    /// The Notion field registered for `keyPath`, or `nil`.
    static func notionProperty(for keyPath: PartialKeyPath<Self>) -> NotionField? {
        notionProperties[keyPath]
    }
    
    mutating func _fetchRelations(using client: NotionClient) async throws { }
}
