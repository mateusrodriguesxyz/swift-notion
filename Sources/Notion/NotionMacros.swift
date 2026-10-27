import Foundation

struct Response<T: Decodable>: Decodable {
    let results: [T]
}

/// The request body of a data source query. Encodes as `{"filter": …}`.
struct QueryBody: Encodable {
    let filter: NotionFilter
}

public enum Notion {
    
    static public func fetch<T: Decodable>(bearerToken: String, dataSourceID: String) async throws -> [T] {
        guard let url = URL(string: "https://api.notion.com/v1/data_sources/\(dataSourceID)/query") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("2026-03-11", forHTTPHeaderField: "Notion-Version")

        let (data, _) = try await URLSession.shared.data(for: request)

        let response = try JSONDecoder().decode(Response<T>.self, from: data)
        return response.results
    }
    
}

public struct NotionClient: Sendable {
    let bearerToken: String
    public init(bearerToken: String) {
        self.bearerToken = bearerToken
    }
    /// Queries a data source. `filter` narrows the results; when `nil` the
    /// request is sent with no body.
    public func fetchPages<T: NotionPage>(dataSourceID: String, filter: NotionFilter? = nil) async throws -> [T] {
        guard let url = URL(string: "https://api.notion.com/v1/data_sources/\(dataSourceID)/query") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("2026-03-11", forHTTPHeaderField: "Notion-Version")

        if let filter {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            request.httpBody = try encoder.encode(QueryBody(filter: filter))
            if let httpBodyJSON = String(data: request.httpBody!, encoding: .utf8) {
                print(httpBodyJSON)
            }
        }

        let (data, _) = try await URLSession.shared.data(for: request)

        let response = try JSONDecoder().decode(Response<T>.self, from: data)
        var results = response.results
        for index in results.indices {
            try await results[index]._fetchRelations(using: self)
        }
        return results
    }

    /// Fetches a single page by its Notion page id. The response is one page
    /// object, so `T` decodes directly (not through `Response`).
    public func fetchPage<T: Decodable>(pageID: String) async throws -> T {
        guard let url = URL(string: "https://api.notion.com/v1/pages/\(pageID)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("2026-03-11", forHTTPHeaderField: "Notion-Version")

        let (data, _) = try await URLSession.shared.data(for: request)

        return try JSONDecoder().decode(T.self, from: data)
    }
    
}

@attached(member, names: arbitrary)
@attached(extension, conformances: NotionPage, Encodable, names: named(notionProperties))
public macro NotionPage() = #externalMacro(module: "NotionMacrosImplementation", type: "NotionPageMacro")

@attached(peer, names: arbitrary)
public macro NotionTitle(_ key: String) = #externalMacro(module: "NotionMacrosImplementation", type: "NotionTitleMacro")

@attached(peer, names: arbitrary)
public macro NotionRichText(_ key: String) = #externalMacro(module: "NotionMacrosImplementation", type: "NotionRichTextMacro")

@attached(peer, names: arbitrary)
public macro NotionFile(_ key: String) = #externalMacro(module: "NotionMacrosImplementation", type: "NotionFileMacro")

@attached(peer, names: arbitrary)
public macro NotionFiles(_ key: String) = #externalMacro(module: "NotionMacrosImplementation", type: "NotionFilesMacro")

@attached(peer, names: arbitrary)
public macro NotionDateStart(_ key: String) = #externalMacro(module: "NotionMacrosImplementation", type: "NotionDateStartMacro")

@attached(peer, names: arbitrary)
public macro NotionDateRange(_ key: String) = #externalMacro(module: "NotionMacrosImplementation", type: "NotionDateRangeMacro")

@attached(peer, names: arbitrary)
public macro NotionRelationIDs(_ key: String) = #externalMacro(module: "NotionMacrosImplementation", type: "NotionRelationIDsMacro")

@attached(peer, names: arbitrary)
public macro NotionCheckbox(_ key: String) = #externalMacro(module: "NotionMacrosImplementation", type: "NotionCheckboxMacro")

@attached(peer, names: arbitrary)
public macro NotionNumber(_ key: String) = #externalMacro(module: "NotionMacrosImplementation", type: "NotionNumberMacro")

/// Infer the decoder from the property's declared Swift type. Supported types:
/// `String`/`String?` (Rich Text)
/// `URL?` (First File URL)
/// `[URL]` (All Files URLs)
/// `Date?` (Start Date)
/// `Range<Date>?` (Start and End Date)
/// `Bool` (Checkbox)
/// `Double?` (Number)
///  The title and relation properties are not inferred; use `@NotionTitle` and `@NotionRelationIDs` for those.
@attached(peer, names: arbitrary)
public macro NotionProperty(_ key: String) = #externalMacro(module: "NotionMacrosImplementation", type: "NotionPropertyMacro")

/// Declares a relation property that fetches related `@NotionPage` objects.
/// The property type must be an array of a `@NotionPage` type, e.g. `[Song]`.
/// Generates a private `_propertyName: [UUID]` backing store for relation IDs,
/// a public `propertyName: [RelatedType] = []` for fetched objects,
/// and a `_fetchRelations(using:)` method that fetches all related pages.
@attached(peer, names: arbitrary)
public macro NotionRelationQuery(_ key: String) = #externalMacro(module: "NotionMacrosImplementation", type: "NotionRelationQueryMacro")
