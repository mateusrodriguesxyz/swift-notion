//
//  NotionFilter.swift
//  SwiftNotion
//

import Foundation

/// A type-safe Notion data source/database query filter. Encodes to the JSON
/// object accepted under the `filter` key of
/// `POST /v1/data_sources/{data_source_id}/query`.
public enum NotionFilter: Encodable, Sendable, Equatable {
    case title(String, TextCondition)
    case richText(String, TextCondition)
    case relation(String, RelationCondition)
    case date(String, DateCondition)
    case select(String, equals: String)
    case multiSelect(String, contains: String)
    case checkbox(String, equals: Bool)
    case number(String, NumberCondition)
    case files(String, FilesCondition)
    case and([NotionFilter])
    case or([NotionFilter])

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: FilterKey.self)
        switch self {
        case .title(let property, let condition):
            try container.encode(property, forKey: .property)
            try container.encode(condition, forKey: .title)
        case .richText(let property, let condition):
            try container.encode(property, forKey: .property)
            try container.encode(condition, forKey: .richText)
        case .relation(let property, let condition):
            try container.encode(property, forKey: .property)
            try container.encode(condition, forKey: .relation)
        case .date(let property, let condition):
            try container.encode(property, forKey: .property)
            try container.encode(condition, forKey: .date)
        case .select(let property, let value):
            try container.encode(property, forKey: .property)
            try container.encode(["equals": value], forKey: .select)
        case .multiSelect(let property, let value):
            try container.encode(property, forKey: .property)
            try container.encode(["contains": value], forKey: .multiSelect)
        case .checkbox(let property, let value):
            try container.encode(property, forKey: .property)
            try container.encode(["equals": value], forKey: .checkbox)
        case .number(let property, let condition):
            try container.encode(property, forKey: .property)
            try container.encode(condition, forKey: .number)
        case .files(let property, let condition):
            try container.encode(property, forKey: .property)
            try container.encode(condition, forKey: .files)
        case .and(let filters):
            var list = container.nestedUnkeyedContainer(forKey: .and)
            for filter in filters { try list.encode(filter) }
        case .or(let filters):
            var list = container.nestedUnkeyedContainer(forKey: .or)
            for filter in filters { try list.encode(filter) }
        }
    }
}

/// Conditions for `title` and rich text properties.
public enum TextCondition: Encodable, Sendable, Equatable {
    case equals(String)
    case doesNotEqual(String)
    case contains(String)
    case doesNotContain(String)
    case startsWith(String)
    case endsWith(String)
    case isEmpty
    case isNotEmpty

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ConditionKey.self)
        switch self {
        case .equals(let value): try container.encode(value, forKey: .equals)
        case .doesNotEqual(let value): try container.encode(value, forKey: .doesNotEqual)
        case .contains(let value): try container.encode(value, forKey: .contains)
        case .doesNotContain(let value): try container.encode(value, forKey: .doesNotContain)
        case .startsWith(let value): try container.encode(value, forKey: .startsWith)
        case .endsWith(let value): try container.encode(value, forKey: .endsWith)
        case .isEmpty: try container.encode(true, forKey: .isEmpty)
        case .isNotEmpty: try container.encode(true, forKey: .isNotEmpty)
        }
    }
}

/// Conditions for `relation` properties.
public enum RelationCondition: Encodable, Sendable, Equatable {
    case contains(UUID)
    case doesNotContain(UUID)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ConditionKey.self)
        switch self {
        case .contains(let id): try container.encode(id.uuidString.lowercased(), forKey: .contains)
        case .doesNotContain(let id): try container.encode(id.uuidString.lowercased(), forKey: .doesNotContain)
        }
    }
}

/// Conditions for `date` properties. Dates are written as `yyyy-MM-dd` in UTC,
/// matching the date-only form read by `NotionDecoding.date(from:)`.
public enum DateCondition: Encodable, Sendable, Equatable {
    case equals(Date)
    case before(Date)
    case after(Date)
    case onOrBefore(Date)
    case onOrAfter(Date)
    case isEmpty
    case isNotEmpty

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ConditionKey.self)
        switch self {
        case .equals(let date): try container.encode(Self.string(from: date), forKey: .equals)
        case .before(let date): try container.encode(Self.string(from: date), forKey: .before)
        case .after(let date): try container.encode(Self.string(from: date), forKey: .after)
        case .onOrBefore(let date): try container.encode(Self.string(from: date), forKey: .onOrBefore)
        case .onOrAfter(let date): try container.encode(Self.string(from: date), forKey: .onOrAfter)
        case .isEmpty: try container.encode(true, forKey: .isEmpty)
        case .isNotEmpty: try container.encode(true, forKey: .isNotEmpty)
        }
    }

    private static func string(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

/// Conditions for `number` properties.
public enum NumberCondition: Encodable, Sendable, Equatable {
    case equals(Double)
    case doesNotEqual(Double)
    case greaterThan(Double)
    case lessThan(Double)
    case greaterThanOrEqualTo(Double)
    case lessThanOrEqualTo(Double)
    case isEmpty
    case isNotEmpty

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ConditionKey.self)
        switch self {
        case .equals(let value): try container.encode(value, forKey: .equals)
        case .doesNotEqual(let value): try container.encode(value, forKey: .doesNotEqual)
        case .greaterThan(let value): try container.encode(value, forKey: .greaterThan)
        case .lessThan(let value): try container.encode(value, forKey: .lessThan)
        case .greaterThanOrEqualTo(let value): try container.encode(value, forKey: .greaterThanOrEqualTo)
        case .lessThanOrEqualTo(let value): try container.encode(value, forKey: .lessThanOrEqualTo)
        case .isEmpty: try container.encode(true, forKey: .isEmpty)
        case .isNotEmpty: try container.encode(true, forKey: .isNotEmpty)
        }
    }
}

/// Conditions for `files` properties. Notion supports only empty/not-empty
/// checks; a single-file and a multi-file property both filter through `files`.
public enum FilesCondition: Encodable, Sendable, Equatable {
    case isEmpty
    case isNotEmpty

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ConditionKey.self)
        switch self {
        case .isEmpty: try container.encode(true, forKey: .isEmpty)
        case .isNotEmpty: try container.encode(true, forKey: .isNotEmpty)
        }
    }
}

/// The property-kind keys of a Notion filter object.
enum FilterKey: String, CodingKey {
    case property
    case title
    case relation
    case date
    case select
    case checkbox
    case number
    case files
    case and
    case or
    case richText = "rich_text"
    case multiSelect = "multi_select"
}

/// The condition keys of a Notion filter, in Notion's snake_case spelling.
enum ConditionKey: String, CodingKey {
    case equals
    case contains
    case before
    case after
    case doesNotEqual = "does_not_equal"
    case doesNotContain = "does_not_contain"
    case startsWith = "starts_with"
    case endsWith = "ends_with"
    case isEmpty = "is_empty"
    case isNotEmpty = "is_not_empty"
    case onOrBefore = "on_or_before"
    case onOrAfter = "on_or_after"
    case greaterThan = "greater_than"
    case lessThan = "less_than"
    case greaterThanOrEqualTo = "greater_than_or_equal_to"
    case lessThanOrEqualTo = "less_than_or_equal_to"
}
