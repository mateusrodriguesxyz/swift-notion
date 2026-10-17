import Foundation

/// Builds the Notion write shape (the object accepted under a `properties`
/// entry of a Create/Update page request) for one `@Notion*`-annotated property
/// value. This is the counterpart of `NotionDecoding`: values wrapped here are
/// emitted in the objects the Notion API expects, not as raw Swift values.
public enum NotionEncoding {}

public extension NotionEncoding {
    /// `{"title":[{"type":"text","text":{"content":…}}]}`, or an empty array
    /// when the content is empty (Notion's way of clearing a title).
    struct Title: Encodable {
        public let content: String

        public init(content: String) {
            self.content = content
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: NotionEncodingKey.self)
            try container.encode(textObjects(for: content), forKey: .title)
        }
    }

    /// `{"rich_text":[{"type":"text","text":{"content":…}}]}`, or an empty array
    /// when the content is empty (Notion's way of clearing a rich text value).
    struct RichText: Encodable {
        public let content: String

        public init(content: String) {
            self.content = content
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: NotionEncodingKey.self)
            try container.encode(textObjects(for: content), forKey: .richText)
        }
    }

    /// `{"files":[{"name":…,"type":"external","external":{"url":…}}]}`. Hosted
    /// Notion files are read-only, so a `URL` is always written back as an
    /// `external` file. `name` defaults to the URL's last path component.
    struct File: Encodable {
        public let url: URL
        public let name: String

        public init(url: URL, name: String? = nil) {
            self.url = url
            self.name = name ?? notionFileName(for: url)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: NotionEncodingKey.self)
            try container.encode([FileObject(name: name, url: url)], forKey: .files)
        }
    }

    /// `{"files":[<file object>, …]}`. An empty array clears the property.
    struct Files: Encodable {
        public let urls: [URL]

        public init(urls: [URL]) {
            self.urls = urls
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: NotionEncodingKey.self)
            let objects = urls.map { FileObject(name: notionFileName(for: $0), url: $0) }
            try container.encode(objects, forKey: .files)
        }
    }

    /// `{"date":{"start":…}}` or `{"date":{"start":…,"end":…}}`. Each bound is
    /// written as `yyyy-MM-dd` when it is midnight UTC, otherwise as an ISO-8601
    /// timestamp. `end` is omitted when `nil`.
    struct DateValue: Encodable {
        public let start: Date
        public let end: Date?

        public init(start: Date, end: Date? = nil) {
            self.start = start
            self.end = end
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: NotionEncodingKey.self)
            var date = container.nestedContainer(keyedBy: NotionEncodingKey.self, forKey: .date)
            try date.encode(NotionDateFormatting.string(from: start), forKey: .start)
            try date.encodeIfPresent(end.map(NotionDateFormatting.string(from:)), forKey: .end)
        }
    }

    /// `{"relation":[{"id":…}]}`. An empty array clears the relation.
    struct Relation: Encodable {
        public let ids: [UUID]

        public init(ids: [UUID]) {
            self.ids = ids
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: NotionEncodingKey.self)
            try container.encode(ids.map(RelationItem.init), forKey: .relation)
        }
    }

    /// `{"checkbox": true|false}`.
    struct Checkbox: Encodable {
        public let value: Bool

        public init(value: Bool) {
            self.value = value
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: NotionEncodingKey.self)
            try container.encode(value, forKey: .checkbox)
        }
    }

    /// `{"number": …}`. `null` clears the value.
    struct Number: Encodable {
        public let value: Double?

        public init(value: Double?) {
            self.value = value
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: NotionEncodingKey.self)
            try container.encode(value, forKey: .number)
        }
    }
}

/// The property-kind keys and the nested keys of the Notion write objects, in
/// Notion's spelling. One shared enum suffices: `CodingKey` only names keys.
enum NotionEncodingKey: String, CodingKey {
    case title
    case richText = "rich_text"
    case files
    case date
    case relation
    case checkbox
    case number
    case start
    case end
    case name
    case type
    case external
    case url
    case id
    case text
    case content
}

/// One Notion rich text object holding a plain string:
/// `{"type":"text","text":{"content":…}}`.
private struct TextObject: Encodable {
    let type = "text"
    let text: TextContent

    init(content: String) {
        self.text = TextContent(content: content)
    }

    struct TextContent: Encodable {
        let content: String
    }
}

/// One Notion file object backed by an external URL:
/// `{"name":…,"type":"external","external":{"url":…}}`.
private struct FileObject: Encodable {
    let name: String
    let url: URL

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: NotionEncodingKey.self)
        try container.encode(name, forKey: .name)
        try container.encode("external", forKey: .type)
        var external = container.nestedContainer(keyedBy: NotionEncodingKey.self, forKey: .external)
        try external.encode(url.absoluteString, forKey: .url)
    }
}

/// One Notion relation reference: `{"id":…}`.
private struct RelationItem: Encodable {
    let id: UUID
}

/// `[]` for empty content, otherwise a single text object.
private func textObjects(for content: String) -> [TextObject] {
    content.isEmpty ? [] : [TextObject(content: content)]
}

/// The `name` Notion requires on a file object; derived from the URL since the
/// DTOs carry only URLs.
private func notionFileName(for url: URL) -> String {
    let last = url.lastPathComponent
    return last.isEmpty ? "file" : last
}

/// Date formatting for Notion writes: `yyyy-MM-dd` at midnight UTC, ISO-8601
/// internet date-time otherwise. Formatters are created per call, matching
/// `DateCondition`, to avoid shared mutable state under Swift 6 concurrency.
private enum NotionDateFormatting {
    static func string(from date: Date) -> String {
        if isMidnightUTC(date) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .iso8601)
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private static func isMidnightUTC(_ date: Date) -> Bool {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        return components.hour == 0
            && components.minute == 0
            && components.second == 0
            && components.nanosecond == 0
    }
}
