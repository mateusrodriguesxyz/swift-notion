import Foundation

public enum NotionDecoding {}

public extension NotionDecoding {
    struct DynamicCodingKey: CodingKey {
        public let stringValue: String
        public let intValue: Int?

        public init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }

        public init?(intValue: Int) {
            self.stringValue = String(intValue)
            self.intValue = intValue
        }
    }

    /// Splits one semicolon-delimited rich-text value into trimmed, non-empty
    /// items. An absent or empty value decodes to an empty array.
    static func stringArray(from string: String?) -> [String] {
        guard let string, !string.isEmpty else { return [] }

        return string
            .components(separatedBy: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Decodes a Notion select option into a `String`-backed enum. Unknown
    /// option names throw instead of silently losing data.
    static func selection<T: RawRepresentable>(
        from value: Selection,
        codingPath: [CodingKey] = []
    ) throws -> T? where T.RawValue == String {
        guard let option = value.select else { return nil }
        return try enumValue(option.name, codingPath: codingPath)
    }

    /// Decodes Notion multi-select options into a `String`-backed enum array.
    /// Unknown option names throw instead of being silently omitted.
    static func multiSelection<T: RawRepresentable>(
        from value: MultiSelection,
        codingPath: [CodingKey] = []
    ) throws -> [T] where T.RawValue == String {
        try value.multiSelect.map { try enumValue($0.name, codingPath: codingPath) }
    }

    private static func enumValue<T: RawRepresentable>(
        _ rawValue: String,
        codingPath: [CodingKey]
    ) throws -> T where T.RawValue == String {
        guard let value = T(rawValue: rawValue) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: codingPath,
                debugDescription: "Unknown \(T.self) option '\(rawValue)'."
            ))
        }
        return value
    }

    /// Parses a Notion `date.start` value, which is either a date-only string
    /// (`2026-09-07`) or an ISO-8601 datetime (with optional fractional seconds
    /// and offset). Returns `nil` for `nil`, empty, or unparseable input.
    static func date(from string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }

        let fractionalISOFormatter = ISO8601DateFormatter()
        fractionalISOFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalISOFormatter.date(from: string) {
            return date
        }

        let plainISOFormatter = ISO8601DateFormatter()
        plainISOFormatter.formatOptions = [.withInternetDateTime]
        if let date = plainISOFormatter.date(from: string) {
            return date
        }

        let dateOnlyFormatter = DateFormatter()
        dateOnlyFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateOnlyFormatter.calendar = Calendar(identifier: .iso8601)
        dateOnlyFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
        if let date = dateOnlyFormatter.date(from: string) {
            return date
        }
        
        return nil
    }

    /// Builds a half-open `Range<Date>` from a Notion date value. Returns `nil`
    /// when either bound is missing or unparseable, or when the end precedes the
    /// start (which would trap when forming the range).
    static func range(from value: DateRange) -> Range<Date>? {
        guard
            let start = date(from: value.start),
            let end = date(from: value.end),
            start <= end
        else {
            return nil
        }
        return start ..< end
    }

    struct RichTextItem: Decodable {
        public let plainText: String?
        enum CodingKeys: String, CodingKey {
            case plainText = "plain_text"
        }
    }

    struct Title: Decodable {
        public let title: [RichTextItem]
    }

    struct RichText: Decodable {
        public let richText: [RichTextItem]
        enum CodingKeys: String, CodingKey {
            case richText = "rich_text"
        }
    }

    struct FileDetail: Decodable {
        public let url: String?
    }

    struct FileValue: Decodable {
        public let file: FileDetail?
    }

    struct Files: Decodable {
        public let files: [FileValue]
    }

    struct DateRange: Decodable {
        public let start: String?
        public let end: String?
    }

    struct DateValue: Decodable {
        public let date: DateRange?
    }

    struct RelationValue: Decodable {
        public let id: String
    }

    struct Relation: Decodable {
        public let relation: [RelationValue]
    }

    struct Checkbox: Decodable {
        public let checkbox: Bool
    }

    struct NumberValue: Decodable {
        public let number: Double?
    }

    struct Selection: Decodable {
        public let select: Option?
    }

    struct MultiSelection: Decodable {
        public let multiSelect: [Option]

        enum CodingKeys: String, CodingKey {
            case multiSelect = "multi_select"
        }
    }

    struct Option: Decodable {
        public let name: String
    }
}
