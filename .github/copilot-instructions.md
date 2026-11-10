# Copilot instructions for SwiftNotion

## Repository shape

This repo is a Swift package named `Notion` built from `Package.swift`.

- Library target: `Sources/Notion`
- Macro implementation target: `Sources/NotionMacrosImplementation`
- Test target: `Tests/NotionMacrosTests`
- Platform targets: iOS 26 and macOS 26

## Build, test, and verification commands

Use Swift Package Manager from the repository root:

- `swift build` — compile the package and macro target
- `swift test` — run the full suite
- `swift test --filter NotionClientTests` — run the main client-focused suite
- `swift test --filter 'NotionClientTests/emptyTitleReportsNotFoundWithoutRequesting'` — run a single Swift Testing case

There is no Makefile, justfile, or dedicated lint script in this repo; the standard verification path is `swift build` and targeted `swift test --filter ...` checks.

## High-level architecture

The package is centered on a Notion API client built around `NotionClient` and a macro-based model layer:

- `NotionClient` handles the REST API: it builds async `URLRequest`s, sends them with `URLSession`, decodes Notion responses, and resolves data-source IDs via `POST /v1/search`.
- `NotionPage` is the model protocol consumed by the `@NotionPage` macro. The macro-generated metadata maps each annotated Swift property to the matching Notion property field and handles relation-fetching behavior.
- `NotionEncoding` and `NotionDecoding` are the normalization layer for Notion-specific JSON shapes (`rich_text`, `files`, `date`, `relation`, `checkbox`, `number`, `select`, `multi_select`, etc.). New property support should usually go through these helpers instead of ad hoc JSON dictionary construction.
- `NotionFilter` and related filter enums define the type-safe query payloads used for `POST /v1/data_sources/{data_source_id}/query` requests, so filter changes are usually done by extending these enums rather than writing raw JSON.
- The tests live under `Tests/NotionMacrosTests` and use Swift Testing (`@Suite`, `@Test`) plus a custom `StubURLProtocol` to validate request payloads, pagination, and error cases.

## Key conventions specific to this repo

- Prefer async/throws APIs. The codebase uses Swift concurrency (`async`, `await`, `Sendable`) consistently rather than callback-based networking.
- Preserve the Notion field spelling and structure exactly when adding a feature. The repo intentionally names keys according to Notion's schema (`plain_text`, `rich_text`, `start`, `end`, `property`, etc.) and encodes/decodes via the shared helpers.
- Keep property-specific logic next to the corresponding Notion model/macro code instead of scattering it through unrelated files. The `@Notion*` macro family and the `Notion*` encoding/decoding types are the canonical integration points. `@NotionProperty` infers select and multi-select fields from optional and array `String`-backed enums; `@NotionSelect` and `@NotionMultiSelect` are available when explicit mapping is preferred. Unknown option names fail decoding.
- Client API failures and missing Notion page properties are surfaced as cases of `NotionError`; API response details are carried by `NotionAPIError`.
- When a change affects Notion page mapping, relation loading, or query filters, validate the relevant `swift test --filter ...` cases rather than only running the entire suite.
- The package is set to Swift tools version 6.2 and uses concurrency-aware patterns, so new code should remain Swift 6-friendly (`Sendable`, value types, actor usage where appropriate).

## Relevant project files

When exploring or changing behavior, these files are usually the correct starting points:

- `Package.swift` — package manifest, target layout, dependencies, and Swift version
- `Sources/Notion/NotionMacros.swift` — public macro declarations and client entry points
- `Sources/Notion/NotionPage.swift` — the `NotionPage` protocol and field metadata contract
- `Sources/Notion/NotionFilter.swift` — type-safe Notion filter definitions
- `Sources/Notion/NotionEncoding.swift` and `Sources/Notion/NotionDecoding.swift` — conversion layer for Notion JSON shapes
- `Sources/NotionMacrosImplementation` — actual macro implementation logic
- `Tests/NotionMacrosTests` — regression tests for API payloads and behavior
