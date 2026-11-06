//
//  NotionAPIErrorTests.swift
//  NotionMacrosTests
//
//  Error body shape follows https://developers.notion.com/reference/errors.
//  The tests extend `NotionClientTests` because `StubURLProtocol` keeps its
//  canned handler in shared static state, so suites that use it must not run
//  in parallel.
//

import Foundation
import Notion
import Testing

@NotionPage
struct StubPageDTO: Decodable {
    @NotionTitle("Name") var name: String
}

@NotionPage
struct AllFieldTypesPageDTO: Decodable {
    @NotionTitle("Name") var name: String
    @NotionProperty("Description") var description: String
    @NotionProperty("Tags") var tags: [String]
    @NotionProperty("Cover") var cover: URL?
    @NotionProperty("Attachments") var attachments: [URL]
    @NotionProperty("Date") var date: Date?
    @NotionProperty("Period") var period: Range<Date>?
    @NotionRelationIDs("Related") var related: [UUID]
    @NotionCheckbox("Done") var done: Bool
    @NotionNumber("Score") var score: Double?
}

private let expectedValidationMessage = #"path failed validation: path.data_source_id should be a valid uuid, instead was `"46e4a8b-0df3-8089-bd4c-000bf8822414"`."#

private let validationErrorBody = #"{"object":"error","status":400,"code":"validation_error","message":"path failed validation: path.data_source_id should be a valid uuid, instead was `\"46e4a8b-0df3-8089-bd4c-000bf8822414\"`.","request_id":"14b67716-6ef0-4dc9-8a22-dfd5e1c49910"}"#

private let unauthorizedBody = #"{"object":"error","status":401,"code":"unauthorized","message":"API token is invalid.","request_id":"6f1a2b3c-4d5e-4f60-8192-a3b4c5d6e7f8"}"#

extension NotionClientTests {
    private func makeErrorClient() -> NotionClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return NotionClient(
            bearerToken: "test-token",
            session: URLSession(configuration: configuration)
        )
    }

    @Test
    func fetchPagesThrowsParsedAPIError() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.setHandler { _ in .init(statusCode: 400, body: validationErrorBody) }

        do {
            let _: [StubPageDTO] = try await makeErrorClient()
                .fetchPages(dataSourceID: "46e4a8b-0df3-8089-bd4c-000bf8822414")
            Issue.record("expected NotionAPIError")
        } catch let error as NotionAPIError {
            #expect(error.object == "error")
            #expect(error.status == 400)
            #expect(error.code == "validation_error")
            #expect(error.message == expectedValidationMessage)
            #expect(error.requestID == "14b67716-6ef0-4dc9-8a22-dfd5e1c49910")
        }
    }

    @Test
    func fetchPageThrowsParsedAPIError() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.setHandler { _ in .init(statusCode: 400, body: validationErrorBody) }

        do {
            let _: StubPageDTO = try await makeErrorClient()
                .fetchPage(pageID: "46e4a8b-0df3-8089-bd4c-000bf8822414")
            Issue.record("expected NotionAPIError")
        } catch let error as NotionAPIError {
            #expect(error.status == 400)
            #expect(error.code == "validation_error")
            #expect(error.requestID == "14b67716-6ef0-4dc9-8a22-dfd5e1c49910")
        }
    }

    @Test
    func dataSourceResolutionThrowsParsedAPIError() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.setHandler { _ in .init(statusCode: 401, body: unauthorizedBody) }

        do {
            _ = try await makeErrorClient().dataSourceID(title: "Artists")
            Issue.record("expected NotionAPIError")
        } catch let error as NotionAPIError {
            #expect(error.status == 401)
            #expect(error.code == "unauthorized")
            #expect(error.message == "API token is invalid.")
        }
    }

    @Test
    func successfulResponseStillDecodes() async throws {
        StubURLProtocol.reset()
        let body = """
        {
          "object": "list",
          "results": [
            {
              "object": "page",
              "id": "0c1f7cb2-8090-4f18-924e-d92965055e32",
              "properties": {
                "Name": { "type": "title", "title": [ { "plain_text": "Page" } ] }
              }
            }
          ],
          "has_more": false,
          "next_cursor": null
        }
        """
        StubURLProtocol.setHandler { _ in .init(body: body) }

        let pages: [StubPageDTO] = try await makeErrorClient().fetchPages(dataSourceID: "ds-1")

        #expect(pages.count == 1)
        #expect(pages.first?.name == "Page")
    }

    @Test
    func fetchPagesThrowsWhenTitlePropertyIsMissing() async throws {
        StubURLProtocol.reset()
        let body = #"""
        {
          "object": "list",
          "results": [
            {
              "object": "page",
              "id": "0c1f7cb2-8090-4f18-924e-d92965055e32",
              "properties": {
                "Nam": { "type": "title", "title": [ { "plain_text": "Page" } ] }
              }
            }
          ],
          "has_more": false,
          "next_cursor": null
        }
        """#
        StubURLProtocol.setHandler { _ in .init(body: body) }

        do {
            let _: [StubPageDTO] = try await makeErrorClient().fetchPages(dataSourceID: "ds-1")
            Issue.record("expected a decoding error for the missing title property")
        } catch DecodingError.keyNotFound(let key, _) {
            #expect(key.stringValue == "Name")
        }
    }

    @Test
    func allFieldTypesThrowWhenTheirPropertyIsMissing() throws {
        let allProperties: [String: [String: Any]] = [
            "Name": ["type": "title", "title": []],
            "Description": ["type": "rich_text", "rich_text": []],
            "Tags": ["type": "rich_text", "rich_text": []],
            "Cover": ["type": "files", "files": []],
            "Attachments": ["type": "files", "files": []],
            "Date": ["type": "date", "date": NSNull()],
            "Period": ["type": "date", "date": NSNull()],
            "Related": ["type": "relation", "relation": []],
            "Done": ["type": "checkbox", "checkbox": false],
            "Score": ["type": "number", "number": NSNull()]
        ]

        for missingProperty in allProperties.keys {
            var properties = allProperties
            properties.removeValue(forKey: missingProperty)
            let page: [String: Any] = [
                "id": "0c1f7cb2-8090-4f18-924e-d92965055e32",
                "properties": properties
            ]
            let data = try JSONSerialization.data(withJSONObject: page)

            do {
                _ = try JSONDecoder().decode(AllFieldTypesPageDTO.self, from: data)
                Issue.record("expected a decoding error for missing property \(missingProperty)")
            } catch DecodingError.keyNotFound(let key, _) {
                #expect(key.stringValue == missingProperty)
            }
        }
    }

}
