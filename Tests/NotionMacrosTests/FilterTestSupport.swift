//
//  FilterTestSupport.swift
//  NotionMacrosTests
//

import Foundation
import NotionMacros
import Testing

/// Reserializes JSON text with sorted keys and no whitespace, so comparisons
/// ignore formatting but keep every key and value. Returns `nil` when `json` is
/// not valid JSON.
func normalizedJSON(_ json: String) -> String? {
    guard let data = json.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data),
          let normalized = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    else { return nil }
    return String(decoding: normalized, as: UTF8.self)
}

/// A UTC midnight date, matching the `yyyy-MM-dd` date-only form Notion writes.
func utcDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar.date(from: components)!
}

/// Encodes a `NotionFilter` as normalized JSON.
func encodedFilterJSON(_ filter: NotionFilter) throws -> String {
    let data = try JSONEncoder().encode(filter)
    let object = try JSONSerialization.jsonObject(with: data)
    let normalized = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    return String(decoding: normalized, as: UTF8.self)
}

/// Encodes a `NotionFilter` as the `{ "filter": ... }` body of a query request,
/// so a test can compare against a documentation snippet verbatim.
func encodedQueryBodyJSON(_ filter: NotionFilter) throws -> String {
    let data = try JSONEncoder().encode(filter)
    let filterObject = try JSONSerialization.jsonObject(with: data)
    let normalized = try JSONSerialization.data(
        withJSONObject: ["filter": filterObject],
        options: [.sortedKeys]
    )
    return String(decoding: normalized, as: UTF8.self)
}

func isUnsupportedRoot(_ error: NotionFilterConversionError) -> Bool {
    if case .unsupportedRoot = error { return true }
    return false
}

func isUnsupportedField(_ error: NotionFilterConversionError) -> Bool {
    if case .unsupportedField = error { return true }
    return false
}

/// Asserts that `predicate` converts to a filter that encodes to `docJSON`, a
/// filter body taken from
/// https://developers.notion.com/reference/filter-data-source-entries.
@available(macOS 14.0, *)
func expectFilter<Root: NotionPage>(
    _ predicate: Predicate<Root>,
    docJSON: String,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    guard let expectedJSON = normalizedJSON(docJSON) else {
        Issue.record("docJSON is not valid JSON: \(docJSON)", sourceLocation: sourceLocation)
        return
    }
    do {
        let filter = try notionFilter(predicate)
        #expect(
            try encodedFilterJSON(filter) == expectedJSON,
            "filter encodes to the documented JSON",
            sourceLocation: sourceLocation
        )
    } catch {
        Issue.record("conversion threw: \(error)", sourceLocation: sourceLocation)
    }
}

/// Asserts that `predicate` cannot be expressed as a `NotionFilter` and that the
/// thrown error satisfies `matches`.
@available(macOS 14.0, *)
func expectConversionError<Root: NotionPage>(
    _ predicate: Predicate<Root>,
    _ comment: Comment,
    matches: (NotionFilterConversionError) -> Bool,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    do {
        _ = try notionFilter(predicate)
        Issue.record("conversion unexpectedly succeeded", sourceLocation: sourceLocation)
    } catch let error as NotionFilterConversionError {
        #expect(matches(error), comment, sourceLocation: sourceLocation)
    } catch {
        Issue.record("unexpected error: \(error)", sourceLocation: sourceLocation)
    }
}

/// Asserts that `filter` encodes to `docJSON`, a filter body taken from
/// https://developers.notion.com/reference/filter-data-source-entries.
func expectEncodes(
    _ filter: NotionFilter,
    docJSON: String,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    guard let expectedJSON = normalizedJSON(docJSON) else {
        Issue.record("docJSON is not valid JSON: \(docJSON)", sourceLocation: sourceLocation)
        return
    }
    do {
        #expect(
            try encodedFilterJSON(filter) == expectedJSON,
            "filter encodes to the documented JSON",
            sourceLocation: sourceLocation
        )
    } catch {
        Issue.record("encoding threw: \(error)", sourceLocation: sourceLocation)
    }
}

/// Asserts that `filter` wrapped in a `"filter"` key matches a full documentation
/// snippet (the shape of a `POST /v1/data_sources/{id}/query` body).
func expectEncodesQueryBody(
    _ filter: NotionFilter,
    docJSON: String,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    guard let expectedJSON = normalizedJSON(docJSON) else {
        Issue.record("docJSON is not valid JSON: \(docJSON)", sourceLocation: sourceLocation)
        return
    }
    do {
        #expect(
            try encodedQueryBodyJSON(filter) == expectedJSON,
            "filter encodes to the documented query body",
            sourceLocation: sourceLocation
        )
    } catch {
        Issue.record("encoding threw: \(error)", sourceLocation: sourceLocation)
    }
}
