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
        case select
        case multiSelect
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

    /// The Notion data source title accepted by `@NotionPage("…")`, or `nil`
    /// when the macro was applied without an argument.
    ///
    /// `NotionClient.fetchPages(ofType:)` resolves this title to a data source
    /// id; types without a title must be queried by id instead.
    static var notionDataSourceTitle: String? { get }

    /// Fetches related pages for all `@NotionRelationProperty` properties.
    /// Default implementation does nothing (for types without relation queries).
    mutating func _fetchRelations(using client: NotionClient) async throws
}

public extension NotionPage {
    /// `nil` unless `@NotionPage("…")` was given a data source title.
    static var notionDataSourceTitle: String? { nil }

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


public func _assertNotionRelationProperty<T: NotionPage>(_ type: T.Type) { }
