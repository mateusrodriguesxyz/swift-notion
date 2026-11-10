import Foundation

struct Response<T: Decodable>: Decodable {
    let results: [T]
}

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

        let (data, response) = try await URLSession.shared.data(for: request)
        let body = try notionResponseData(data, response)

        let result = try JSONDecoder().decode(Response<T>.self, from: body)
        return result.results
    }
    
}

public struct NotionClient: Sendable {
    let bearerToken: String
    let session: URLSession
    let dataSourceIDCache = NotionDataSourceCache()

    public init(bearerToken: String, session: URLSession = .shared) {
        self.bearerToken = bearerToken
        self.session = session
    }
    /// Queries the data source declared by `@NotionPage("…")`.
    ///
    /// The title is resolved to a data source id through `POST /v1/search`
    /// (see `dataSourceID(title:)`) and cached for the lifetime of the client.
    ///
    /// - Throws: `NotionDataSourceError.missingTitle` when `T` was declared
    ///   without a title.
    public func fetchPages<T: NotionPage>(
        ofType type: T.Type,
        filter: NotionFilter? = nil
    ) async throws -> [T] {
        let dataSourceID = try await self.dataSourceID(ofType: type)
        return try await fetchPages(dataSourceID: dataSourceID, filter: filter)
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

        let (data, response) = try await session.data(for: request)
        let body = try notionResponseData(data, response)
        let result = try JSONDecoder().decode(Response<T>.self, from: body)
        var results = result.results
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

        let (data, response) = try await session.data(for: request)
        let body = try notionResponseData(data, response)

        return try JSONDecoder().decode(T.self, from: body)
    }
    
}

@attached(member, names: arbitrary)
@attached(extension, conformances: NotionPage, Encodable, names: named(notionProperties), named(notionDataSourceTitle))
public macro NotionPage(_ dataSourceTitle: String? = nil) = #externalMacro(module: "NotionMacrosImplementation", type: "NotionPageMacro")

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

@attached(peer, names: arbitrary)
public macro NotionSelect(_ key: String) = #externalMacro(module: "NotionMacrosImplementation", type: "NotionSelectMacro")

@attached(peer, names: arbitrary)
public macro NotionMultiSelect(_ key: String) = #externalMacro(module: "NotionMacrosImplementation", type: "NotionMultiSelectMacro")

/// Infer the decoder from the property's declared Swift type. Supported types:
/// `String`/`String?` (Rich Text)
/// `URL?` (First File URL)
/// `[URL]` (All Files URLs)
/// `Date?` (Start Date)
/// `Range<Date>?` (Start and End Date)
/// `Bool` (Checkbox)
/// `Double?` (Number)
/// `SomeEnum?` where `SomeEnum.RawValue == String` (Select)
/// `[SomeEnum]` where `SomeEnum.RawValue == String` (Multi-select)
///  The title and relation properties are not inferred; use `@NotionTitleProperty` and `@NotionRelationProperty` for those.
@attached(peer, names: arbitrary)
public macro NotionProperty(_ key: String) = #externalMacro(module: "NotionMacrosImplementation", type: "NotionPropertyMacro")

@attached(peer, names: arbitrary)
public macro NotionRelationProperty(_ key: String) = #externalMacro(module: "NotionMacrosImplementation", type: "NotionRelationPropertyMacro")

/// Deprecated spelling of `@NotionRelationProperty`.
@available(*, deprecated, renamed: "NotionRelationProperty")
@attached(peer, names: arbitrary)
public macro NotionRelationQuery(_ key: String) = #externalMacro(module: "NotionMacrosImplementation", type: "NotionRelationPropertyMacro")

@attached(peer, names: arbitrary)
public macro NotionTitleProperty(_ key: String) = #externalMacro(module: "NotionMacrosImplementation", type: "NotionTitleMacro")

@available(*, deprecated, renamed: "NotionTitleProperty")
@attached(peer, names: arbitrary)
public macro NotionTitle(_ key: String) = #externalMacro(module: "NotionMacrosImplementation", type: "NotionTitleMacro")
