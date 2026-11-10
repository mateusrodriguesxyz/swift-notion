//
//  NotionClientTests.swift
//  NotionMacrosTests
//
//  Expected response shapes follow https://developers.notion.com/reference/post-search.
//

import Foundation
import Notion
import Testing

@NotionPage("Artists")
struct ArtistPage: Decodable {
    @NotionTitle("Name") var name: String
}

@NotionPage
struct UntitledPage: Decodable {
    @NotionTitle("Name") var name: String
}

@Suite(.serialized)
struct NotionClientTests {
    private func makeClient() -> NotionClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return NotionClient(
            bearerToken: "test-token",
            session: URLSession(configuration: configuration)
        )
    }

    private func searchPage(
        _ results: String,
        hasMore: Bool = false,
        nextCursor: String? = nil
    ) -> String {
        let cursor = nextCursor.map { "\"\($0)\"" } ?? "null"
        return """
        {
          "object": "list",
          "results": [\(results)],
          "has_more": \(hasMore),
          "next_cursor": \(cursor)
        }
        """
    }

    private func dataSource(id: String, title: String) -> String {
        """
        {
          "object": "data_source",
          "id": "\(id)",
          "title": [{ "type": "text", "plain_text": "\(title)", "href": null }]
        }
        """
    }

    private func page(id: String, name: String) -> String {
        """
        {
          "object": "page",
          "id": "\(id)",
          "properties": {
            "Name": { "type": "title", "title": [ { "plain_text": "\(name)" } ] }
          }
        }
        """
    }

    /// Routes search and query requests to separate canned responses.
    private func route(
        search: String,
        query: String
    ) -> (URLRequest) -> StubURLProtocol.Stub {
        { request in
            request.url?.path == "/v1/search"
                ? .init(body: search)
                : .init(body: query)
        }
    }

    @Test
    func emptyTitleReportsNotFoundWithoutRequesting() async throws {
        StubURLProtocol.reset()
        let client = makeClient()

        do {
            _ = try await client.dataSourceID(title: "   ")
            Issue.record("expected notFound")
        } catch let error as NotionDataSourceError {
            #expect(error == .notFound(""))
        }

        #expect(StubURLProtocol.requests.isEmpty)
    }

    @Test
    func resolvesExactTitleAmongFuzzyMatches() async throws {
        StubURLProtocol.reset()
        let page = searchPage(
            [
                dataSource(id: "ds-archive", title: "Artists Archive"),
                dataSource(id: "ds-artists", title: "Artists")
            ].joined(separator: ",")
        )
        StubURLProtocol.setHandler { _ in .init(body: page) }

        let id = try await makeClient().dataSourceID(title: "Artists")

        #expect(id == "ds-artists")

        let request = try #require(StubURLProtocol.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://api.notion.com/v1/search")
        #expect(request.value(forHTTPHeaderField: "Notion-Version") == "2026-03-11")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")

        let body = try #require(StubURLProtocol.body(of: request))
        #expect(body.contains("\"query\":\"Artists\""))
        #expect(body.contains("\"property\":\"object\""))
        #expect(body.contains("\"value\":\"data_source\""))
    }

    @Test
    func matchesTitleTrimmedAndCaseInsensitively() async throws {
        StubURLProtocol.reset()
        let page = searchPage(dataSource(id: "ds-artists", title: "Artists"))
        StubURLProtocol.setHandler { _ in .init(body: page) }

        let id = try await makeClient().dataSourceID(title: "  artists ")

        #expect(id == "ds-artists")
    }

    @Test
    func followsPaginationUntilExactMatch() async throws {
        StubURLProtocol.reset()
        let firstPage = searchPage(
            dataSource(id: "ds-archive", title: "Artists Archive"),
            hasMore: true,
            nextCursor: "cursor-2"
        )
        let secondPage = searchPage(dataSource(id: "ds-artists", title: "Artists"))
        StubURLProtocol.setHandler { request in
            let body = StubURLProtocol.body(of: request) ?? ""
            return .init(body: body.contains("\"start_cursor\":\"cursor-2\"") ? secondPage : firstPage)
        }

        let id = try await makeClient().dataSourceID(title: "Artists")

        #expect(id == "ds-artists")
        #expect(StubURLProtocol.requests.count == 2)
    }

    @Test
    func reportsNotFoundWhenOnlyFuzzyMatchesExist() async throws {
        StubURLProtocol.reset()
        let page = searchPage(dataSource(id: "ds-archive", title: "Artists Archive"))
        StubURLProtocol.setHandler { _ in .init(body: page) }

        do {
            _ = try await makeClient().dataSourceID(title: "Artists")
            Issue.record("expected notFound")
        } catch let error as NotionDataSourceError {
            #expect(error == .notFound("Artists"))
        }
    }

    @Test
    func skipsResultsWithoutTitle() async throws {
        StubURLProtocol.reset()
        let page = searchPage(
            [
                #"{ "object": "data_source", "id": "ds-partial" }"#,
                dataSource(id: "ds-artists", title: "Artists")
            ].joined(separator: ",")
        )
        StubURLProtocol.setHandler { _ in .init(body: page) }

        let id = try await makeClient().dataSourceID(title: "Artists")

        #expect(id == "ds-artists")
    }

    @Test
    func reportsAmbiguousWhenTitlesRepeat() async throws {
        StubURLProtocol.reset()
        let page = searchPage(
            [
                dataSource(id: "ds-1", title: "Tasks"),
                dataSource(id: "ds-2", title: "Tasks")
            ].joined(separator: ",")
        )
        StubURLProtocol.setHandler { _ in .init(body: page) }

        do {
            _ = try await makeClient().dataSourceID(title: "Tasks")
            Issue.record("expected ambiguous")
        } catch let error as NotionDataSourceError {
            #expect(error == .ambiguous("Tasks", ["ds-1", "ds-2"]))
        }
    }

    @Test
    func cachesResolvedIDsPerClient() async throws {
        StubURLProtocol.reset()
        let page = searchPage(dataSource(id: "ds-artists", title: "Artists"))
        StubURLProtocol.setHandler { _ in .init(body: page) }
        let client = makeClient()

        let first = try await client.dataSourceID(title: "Artists")
        let second = try await client.dataSourceID(title: "Artists")

        #expect(first == second)
        #expect(StubURLProtocol.requests.count == 1)
    }

    @Test
    func macroStoresDeclaredDataSourceTitle() {
        #expect(ArtistPage.notionDataSourceTitle == "Artists")
        #expect(UntitledPage.notionDataSourceTitle == nil)
    }

    @Test
    func fetchesPagesByDeclaredDataSourceTitle() async throws {
        StubURLProtocol.reset()
        let search = searchPage(dataSource(id: "ds-artists", title: "Artists"))
        let query = """
        {
          "object": "list",
          "results": [\(page(id: "page-1", name: "Radiohead"))],
          "has_more": false,
          "next_cursor": null
        }
        """
        StubURLProtocol.setHandler(route(search: search, query: query))

        let pages = try await makeClient().fetchPages(ofType: ArtistPage.self)

        #expect(pages.map(\.name) == ["Radiohead"])
        #expect(StubURLProtocol.requests.map { $0.url?.path } == [
            "/v1/search",
            "/v1/data_sources/ds-artists/query",
        ])
    }

    @Test
    func forwardsFilterThroughTypedFetch() async throws {
        StubURLProtocol.reset()
        let search = searchPage(dataSource(id: "ds-artists", title: "Artists"))
        let query = """
        {
          "object": "list",
          "results": [],
          "has_more": false,
          "next_cursor": null
        }
        """
        StubURLProtocol.setHandler(route(search: search, query: query))

        _ = try await makeClient().fetchPages(
            ofType: ArtistPage.self,
            filter: .title("Name", .equals("Radiohead"))
        )

        let queryRequest = try #require(StubURLProtocol.requests.last)
        #expect(queryRequest.url?.absoluteString == "https://api.notion.com/v1/data_sources/ds-artists/query")
        let body = try #require(StubURLProtocol.body(of: queryRequest))
        let compact = body
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
        #expect(compact.contains("\"property\":\"Name\""))
        #expect(compact.contains("\"equals\":\"Radiohead\""))
    }

    @Test
    func reusesResolvedIDAcrossTypedFetches() async throws {
        StubURLProtocol.reset()
        let search = searchPage(dataSource(id: "ds-artists", title: "Artists"))
        let query = """
        {
          "object": "list",
          "results": [],
          "has_more": false,
          "next_cursor": null
        }
        """
        StubURLProtocol.setHandler(route(search: search, query: query))
        let client = makeClient()

        _ = try await client.fetchPages(ofType: ArtistPage.self)
        _ = try await client.fetchPages(ofType: ArtistPage.self)

        let searches = StubURLProtocol.requests.filter { $0.url?.path == "/v1/search" }
        #expect(searches.count == 1)
        #expect(StubURLProtocol.requests.count == 3)
    }

    @Test
    func reportsMissingTitleWithoutRequesting() async throws {
        StubURLProtocol.reset()

        do {
            _ = try await makeClient().fetchPages(ofType: UntitledPage.self)
            Issue.record("expected missingTitle")
        } catch let error as NotionDataSourceError {
            #expect(error == .missingTitle("UntitledPage"))
        }

        #expect(StubURLProtocol.requests.isEmpty)
    }
}
