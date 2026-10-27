# AGENTS.md — SwiftNotion

## What this is

A local Swift macro package (`SwiftNotion`) that synthesizes `Decodable`/`Encodable` conformance for Notion DTOs used by the sibling `ArteAbertaCearaApple` iOS app. Referenced as an `XCLocalSwiftPackageReference` in the workspace.

**See parent `AGENTS.md`** for workspace layout, version control gotchas, and Notion API notes.

## Commands

```bash
# Run all tests (swift-testing suites in Tests/NotionMacrosTests)
swift test

# Run the macro client (decodes inline JSON fixtures; exits non-zero on failure)
swift run NotionMacrosClient
```

## Macro package mechanics

`@NotionPage` = `MemberMacro` + `ExtensionMacro`. Member expansion emits `CodingKeys`, `PropertyKeys`, `id`, `init(from:)`, `encode(to:)`. Extension expansion auto-conforms to `NotionPage` + `Encodable` and synthesizes `static var notionProperties: [PartialKeyPath<Self>: NotionField]`.

Individual `@Notion*` attributes are no-op `PeerMacro`s used only as markers.

**Adding/renaming a Notion attribute requires touching 4 files:**
1. `Sources/SwiftNotion/NotionMacros.swift` — `#externalMacro` declaration
2. `Sources/NotionMacrosImplementation/Plugin.swift` — register macro type
3. `Sources/NotionMacrosImplementation/OtherMacros.swift` — marker `PeerMacro`
4. `Sources/NotionMacrosImplementation/NotionPageMacro.swift` — add `decodeLine` case **and** `encodedValueExpression` case

Shared value types: `Sources/SwiftNotion/NotionDecoding.swift` (read), `Sources/SwiftNotion/NotionEncoding.swift` (write).

**DTO fixtures** in `Sources/NotionMacrosClient/main.swift` mirror `ArteAbertaCearaApple/NotionModels.swift`. Keep in sync.

## Type constraints per attribute

| Attribute | Swift type | Notes |
|-----------|------------|-------|
| `@NotionTitle` | `String` | Required |
| `@NotionRichText` | `String` / `String?` | |
| `@NotionProperty` | Infers from type: `String`/`String?`→rich text, `URL?`→file, `[URL]`→files, `Date?`→date start, `Range<Date>?`→date range, `Bool`→checkbox, `Double?`→number | Other types = compile error |
| `@NotionFile` | `URL?` | Reads only hosted `file.url` |
| `@NotionFiles` | `[URL]` | Reads only hosted `file.url` |
| `@NotionDateStart` | `Date?` | Spell `Date?`, not `Foundation.Date?` |
| `@NotionDateRange` | `Range<Date>?` | Half-open `start..<end`; `nil` if invalid/missing |
| `@NotionCheckbox` | `Bool` | Missing → `false` |
| `@NotionNumber` | `Double?` | Null/empty → `nil` |
| `@NotionRelationIDs` | `[UUID]` | Malformed UUIDs silently dropped |

**Rules:**
- `@NotionPage` applies `Encodable` unconditionally — do not also declare `extension T: Encodable`.
- `URL`, `Date`, `Range<Date>` must be optional; qualified types (`Foundation.URL?`) not recognized.
- `@NotionPage` `id` is `UUID` (zero UUID fallback), so relation IDs compare directly.
- No two properties can share the same Notion key (duplicate `PropertyKeys` raw values).

## Predicate → NotionFilter conversion (`notionFilter(_:)` / `NotionFilter.predicate(_:)`)

Available on macOS 14+. Throws `NotionFilterConversionError` when inexpressible.

**Supported root nodes:**
- `Equal`/`NotEqual`: title/rich text equality, checkbox equality (`Bool`), `== nil`/`!= nil` on file field → `files.is_empty`/`is_not_empty`
- `SequenceContains`: relation `contains` (e.g. `$0.artistIDs.contains(id)`)
- `CollectionContainsCollection`: title/rich text `contains` (e.g. `$0.bio.contains("x")`)
- `SequenceStartsWith`: title/rich text `starts_with` (**not negatable**)
- `KeyPath`: `$0.files.isEmpty` → `files.is_empty` (only `[URL]` shape)
- Bare checkbox property: `$0.published` → `checkbox.equals: true`
- `Negation` of negatable leaves: `Equal`/`NotEqual`→`does_not_equal`, `SequenceContains`→`does_not_contain`, `CollectionContainsCollection`→`does_not_contain`, `KeyPath`→`is_not_empty`, bare checkbox→`equals: false`

**Unsupported:** compound `and`/`or`, `starts_with` negation, file URL equality, non-checkbox `Bool` key paths, unregistered properties.

**Captured values** (e.g. `artist.id`) resolve by evaluation — requires captured type to be `Encodable` (auto-satisfied for `@NotionPage` types).

**Adding new literal operand types:** conform to `NotionFilterOperand` in `PredicateFilter.swift` (currently `String`, `UUID`, `Bool`). `Value` conforms to `NotionFilterOperandExpression` only once.

## Tests

- `PredicateFilterTests`: converts `#Predicate`s; expected JSON from Notion docs.
- `FilterDocsParityTests`: encodes `NotionFilter` cases that have no predicate route; lists unmodelled filter kinds (formula, rollup, people, status, timestamp, verification, unique_id, relative dates, select/multi-select arrays).
- `NotionMacrosClient`: integration-style decode/encode/round-trip against inline fixtures.