# `@NotionRelationQuery` Macro Implementation Spec

## Overview

Adds a new `@NotionRelationQuery` attribute to `@NotionPage` types that:
1. Declares a relation property backed by UUIDs from Notion
2. Generates a private `_propertyName: [UUID]` backing store
3. Initializes the user's declared property to `[]` (empty array)
4. Synthesizes `_fetchRelations(using:)` to fetch related pages concurrently

---

## Macro Usage

```swift
@NotionPage
struct Album: Decodable {
    @NotionTitle("Name") var name: String
    @NotionProperty("Cover") var cover: URL?
    @NotionProperty("Artists") var artists: String
    @NotionRelationQuery("Songs") var songs: [Song]
}
```

- Property type **must** be an array of a `@NotionPage` type (e.g., `[Song]`)
- The array element type (`Song`) is used as the fetch target type

---

## Generated Code

### Properties

```swift
// User's original property (unchanged)
var songs: [Song]

// Private backing store for relation IDs (generated)
var _songs: [UUID] = []
```

### PropertyKeys

```swift
enum PropertyKeys: String, CodingKey {
    case name = "Name"
    case cover = "Cover"
    case artists = "Artists"
    case songs = "Songs"  // uses the Notion field name
}
```

### Decoder (`init(from:)`)

```swift
init(from decoder: Decoder) throws {
    let root = try decoder.container(keyedBy: CodingKeys.self)
    self.id = (try? root.decode(String.self, forKey: .id)).flatMap(UUID.init(uuidString:)) ?? UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    let properties = try root.nestedContainer(keyedBy: PropertyKeys.self, forKey: .properties)
    
    // ... other properties ...
    
    // Decode relation IDs into backing store
    self._songs = (try? properties.decode(SwiftNotion.NotionDecoding.Relation.self, forKey: .songs))?.relation.compactMap { UUID(uuidString: $0.id) } ?? []
    
    // Initialize user's property to empty array
    self.songs = []
}
```

### Encoder (`encode(to:)`)

```swift
func encode(to encoder: any Encoder) throws {
    var root = encoder.container(keyedBy: CodingKeys.self)
    var properties = root.nestedContainer(keyedBy: PropertyKeys.self, forKey: .properties)
    
    // ... other properties ...
    
    // Encode backing store as Notion relation
    try properties.encode(SwiftNotion.NotionEncoding.Relation(ids: self._songs), forKey: .songs)
}
```

### Fetch Methods

```swift
// Public entry point - called by NotionClient.fetchPages for types with @NotionRelationQuery
mutating func _fetchRelations(using client: NotionClient) async throws {
    try await _fetchSongs(using: client)
    // ... one call per @NotionRelationQuery property ...
}

// Per-property fetch helper (concurrent, fail-fast on first error)
private mutating func _fetchSongs(using client: NotionClient) async throws {
    self.songs = try await withThrowingTaskGroup(of: Song.self) { group in
        for id in _songs {
            group.addTask {
                try await client.fetchPage(pageID: id.uuidString.lowercased())
            }
        }
        var results: [Song] = []
        for try await page in group { results.append(page) }
        return results
    }
}
```

### NotionPage Extension

```swift
extension Album: SwiftNotion.NotionPage, Encodable {
    static var notionProperties: [PartialKeyPath<Album>: SwiftNotion.NotionField] {
        [
            \Album.name: SwiftNotion.NotionField(name: "Name", kind: .title),
            \Album.cover: SwiftNotion.NotionField(name: "Cover", kind: .file),
            \Album.artists: SwiftNotion.NotionField(name: "Artists", kind: .richText),
            \Album._songs: SwiftNotion.NotionField(name: "Songs", kind: .relation),  // uses backing store
        ]
    }
}
```

---

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **No `@MainActor` on fetch tasks** | Network I/O runs on background executors |
| **Fail-fast on first error** | Uses `withThrowingTaskGroup` - cancels remaining on error |
| **Backing store `_propertyName`** | Separates Notion relation IDs from fetched objects |
| **User's property unchanged** | Macro doesn't redeclare; initializes to `[]` in `init(from:)` |
| **Protocol default impl** | `NotionPage` has `mutating func _fetchRelations(...) { }` no-op default |

---

## Files Modified

| File | Changes |
|------|---------|
| `Sources/SwiftNotion/NotionMacros.swift` | `#externalMacro` declaration; `NotionClient.fetchPages` calls `_fetchRelations` |
| `Sources/SwiftNotion/NotionPage.swift` | Default `_fetchRelations` implementation |
| `Sources/NotionMacrosImplementation/Plugin.swift` | Register `NotionRelationQueryMacro` |
| `Sources/NotionMacrosImplementation/OtherMacros.swift` | `NotionRelationQueryMacro: PeerMacro` |
| `Sources/NotionMacrosImplementation/NotionPropertyInfo.swift` | Added `relatedType: String?` |
| `Sources/NotionMacrosImplementation/NotionPageMacro.swift` | Core implementation (scan, resolve, generate) |

---

## Validation Rules (in `resolvedProperties`)

- `@NotionRelationQuery` attribute present
- Property type is an array (`[RelatedType]`)
- Element type is a simple identifier (e.g., `Song`, not `Optional<Song>` or complex generic)

---

## Multiple Relation Queries

```swift
@NotionPage
struct Album: Decodable {
    @NotionRelationQuery("Songs") var songs: [Song]
    @NotionRelationQuery("Artists") var artists: [Artist]
}
```

Generates:
- `_songs: [UUID]`, `_artists: [UUID]`
- `songs = []`, `artists = []` in initializer
- `_fetchRelations` calls `_fetchSongs` then `_fetchArtists`
- Both `_fetchSongs` and `_fetchArtists` use concurrent `withThrowingTaskGroup`

---

## NotionClient Integration

```swift
public func fetchPages<T: NotionPage>(...) async throws -> [T] {
    // ... fetch and decode ...
    var results = response.results
    for index in results.indices {
        try await results[index]._fetchRelations(using: self)  // no-op for types without @NotionRelationQuery
    }
    return results
}
```

All `@NotionPage` types have `_fetchRelations` (default no-op), so call is unconditional.

---

## Test Coverage

`Sources/NotionMacrosClient/main.swift` includes:
- `SongDTO` and `AlbumDTO` test types
- JSON fixture with relations
- Tests for: decode populates `_songs`/`_artists`, properties empty initially, encode writes backing store, `notionProperties` map uses `_propertyName` key paths