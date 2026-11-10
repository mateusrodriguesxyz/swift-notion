//
//  NotionDataSourceResolver.swift
//  SwiftNotion
//

import Foundation

/// Errors thrown when resolving a data source title to its Notion id.
public enum NotionDataSourceError: Error, Equatable, Sendable {
    /// No data source with the requested title is shared with the integration.
    /// An empty or whitespace-only title also reports `notFound("")`.
    case notFound(String)
    /// More than one data source carries the requested title; the ids are the
    /// candidates. Notion does not enforce unique data source titles.
    case ambiguous(String, [String])
    /// The page type was declared without a data source title, e.g.
    /// `@NotionPage` instead of `@NotionPage("Album")`.
    case missingTitle(String)
}

/// Resolves data source titles to their ids through `POST /v1/search`, which
/// only sees data sources shared with the integration.
public extension NotionClient {
    /// Returns the id of the data source titled by `type`'s
    /// `@NotionPage("…")` declaration.
    ///
    /// - Throws: `NotionDataSourceError.missingTitle` when `type` has no title.
    func dataSourceID<T: NotionPage>(ofType type: T.Type) async throws -> String {
        guard let title = type.notionDataSourceTitle?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !title.isEmpty
        else {
            throw NotionDataSourceError.missingTitle(String(describing: type))
        }
        return try await dataSourceID(title: title)
    }

    /// Returns the id of the data source titled `title`.
    ///
    /// The title is compared trimmed and case-insensitively against the search
    /// results, because the search endpoint matches substrings. Results that
    /// omit their `title` (partial data source objects) cannot be matched and
    /// are skipped. Successful resolutions are cached for the lifetime of the
    /// client.
    func dataSourceID(title: String) async throws -> String {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw NotionDataSourceError.notFound("") }

        if let cached = await dataSourceIDCache.id(for: title) {
            return cached
        }

        var cursor: String?
        var matches: [String] = []
        var hasMore = true

        while hasMore && matches.isEmpty {
            let page = try await searchDataSources(title: title, startCursor: cursor)

            for result in page.results where result.object == "data_source" {
                guard let resultTitle = result.title?.map(\.plainText).joined(),
                      resultTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        .caseInsensitiveCompare(title) == .orderedSame
                else { continue }

                matches.append(result.id)
            }

            cursor = page.nextCursor
            hasMore = page.hasMore && cursor != nil
        }

        switch matches.count {
        case 1:
            await dataSourceIDCache.store(matches[0], for: title)
            return matches[0]
        case 0:
            throw NotionDataSourceError.notFound(title)
        default:
            throw NotionDataSourceError.ambiguous(title, matches)
        }
    }
}

private extension NotionClient {
    func searchDataSources(title: String, startCursor: String?) async throws -> DataSourceSearchResponse {
        guard let url = URL(string: "https://api.notion.com/v1/search") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("2026-03-11", forHTTPHeaderField: "Notion-Version")
        request.httpBody = try JSONEncoder().encode(
            DataSourceSearchRequest(query: title, startCursor: startCursor)
        )

        let (data, response) = try await session.data(for: request)
        let body = try notionResponseData(data, response)
        return try JSONDecoder().decode(DataSourceSearchResponse.self, from: body)
    }
}

/// The body of a `POST /v1/search` request restricted to data sources.
struct DataSourceSearchRequest: Encodable, Sendable {
    let query: String
    var pageSize: Int = 100
    var startCursor: String?
    var filter = Filter()

    struct Filter: Encodable, Sendable {
        let property = "object"
        let value = "data_source"
    }

    enum CodingKeys: String, CodingKey {
        case query
        case pageSize = "page_size"
        case startCursor = "start_cursor"
        case filter
    }
}

/// The paginated `POST /v1/search` response, narrowed to the fields the title
/// resolver reads.
struct DataSourceSearchResponse: Decodable, Sendable {
    let results: [Result]
    let hasMore: Bool
    let nextCursor: String?

    struct Result: Decodable, Sendable {
        let object: String
        let id: String
        let title: [RichText]?

        struct RichText: Decodable, Sendable {
            let plainText: String

            enum CodingKeys: String, CodingKey {
                case plainText = "plain_text"
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case results
        case hasMore = "has_more"
        case nextCursor = "next_cursor"
    }
}

/// Caches resolved data source ids for one `NotionClient` instance.
actor NotionDataSourceCache {
    private var ids: [String: String] = [:]

    func id(for title: String) -> String? {
        ids[title]
    }

    func store(_ id: String, for title: String) {
        ids[title] = id
    }
}
