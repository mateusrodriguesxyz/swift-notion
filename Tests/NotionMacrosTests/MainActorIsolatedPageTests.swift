import Testing
import Foundation
@testable import Notion

// Regression: an isolated @NotionPage type must still be usable from the
// nonisolated relation fetch helpers (`group.addTask`) without
// "main actor-isolated conformance ... cannot be used in @concurrent context".
@MainActor
@NotionPage("Songs")
struct IsolatedSongDTO {
    @NotionTitle("Name") var name: String
}

@MainActor
@NotionPage
struct IsolatedArtistDTO {
    @NotionTitle("Name") var name: String
    @NotionRelationProperty("Songs") var songs: [IsolatedSongDTO]
}

@Suite struct MainActorIsolatedPageTests {
    @Test func isolatedPageTypesCompileAndExposeNotionFields() {
        #expect(IsolatedArtistDTO.notionProperties.count == 2)
        #expect(IsolatedSongDTO.notionDataSourceTitle == "Songs")
    }
}
