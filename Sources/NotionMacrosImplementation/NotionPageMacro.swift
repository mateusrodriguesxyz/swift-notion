import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros



public struct NotionPageMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let properties = try resolvedProperties(of: declaration)

        guard !properties.isEmpty else { return [] }

        let isPublic = declaration.modifiers.contains { $0.name.text == "public" || $0.name.text == "open" }
        let access = isPublic ? "public " : ""

        let keyCases = properties
            .map { "        case \($0.identifier) = \"\($0.key)\"" }
            .joined(separator: "\n")

        // For @NotionRelationQuery, decode into the backing store (_identifier)
        let decodeLines = properties
            .compactMap { prop -> String? in
                if prop.attribute == "NotionRelation" && prop.relatedType != nil {
                    // This is a @NotionRelationQuery - decode into _identifier
                    return "self._\(prop.identifier) = (try? properties.decode(NotionDecoding.Relation.self, forKey: .\(prop.identifier)))?.relation.compactMap { UUID(uuidString: $0.id) } ?? []"
                }
                return decodeLine(for: prop.attribute, identifier: prop.identifier)
            }
            .joined(separator: "\n        ")

        let codingKeys = """
        enum CodingKeys: String, CodingKey {
            case id
            case properties
        }
        """

        let propertyKeys = """
        enum PropertyKeys: String, CodingKey {
        \(keyCases)
        }
        """

        let idProperty = "\(access)let id: UUID"

        // Generate backing store properties for @NotionRelationQuery
        let relationQueryProperties = properties
            .filter { $0.attribute == "NotionRelation" && $0.relatedType != nil }
            .map { prop in
                return "\(access)var _\(prop.identifier): [UUID] = []"
            }
            .joined(separator: "\n")

        // Initialize user's relation query properties to empty arrays in initializer
        let relationQueryInits = properties
            .filter { $0.attribute == "NotionRelation" && $0.relatedType != nil }
            .map { "self.\($0.identifier) = []" }
            .joined(separator: "\n        ")

        let initializer = """
        \(access)init(from decoder: Decoder) throws {
            let root = try decoder.container(keyedBy: CodingKeys.self)
            self.id = (try? root.decode(String.self, forKey: .id)).flatMap(UUID.init(uuidString:)) ?? UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
            let properties = try root.nestedContainer(keyedBy: PropertyKeys.self, forKey: .properties)
            \(decodeLines)
            \(relationQueryInits.isEmpty ? "" : relationQueryInits)
        }
        """

        let encodeLines = properties
            .map { prop -> String in
                if prop.attribute == "NotionRelation" && prop.relatedType != nil {
                    // @NotionRelationQuery - encode the backing store _identifier
                    return "try properties.encode(NotionEncoding.Relation(ids: self._\(prop.identifier)), forKey: .\(prop.identifier))"
                }
                return encodeLine(for: prop)
            }
            .joined(separator: "\n    ")

        // Emitted as a member, not through the extension expansion, so it is
        // covered by `names: arbitrary`. The extension expansion declares the
        // `Encodable` conformance that this member satisfies.
        //
        // The output is the write shape of a Create/Update page request body:
        // `{ "properties": { <Notion field name>: <Notion property object> } }`.
        // `id` is deliberately not encoded; it is read-only on the write side.
        let encoder = """
        \(access)func encode(to encoder: any Encoder) throws {
            var root = encoder.container(keyedBy: CodingKeys.self)
            var properties = root.nestedContainer(keyedBy: PropertyKeys.self, forKey: .properties)
            \(encodeLines)
        }
        """

        // Generate _fetchRelations and per-property fetch helpers
        let fetchMethods = generateFetchMethods(for: properties, access: access)

        var members: [DeclSyntax] = [
            DeclSyntax(stringLiteral: codingKeys),
            DeclSyntax(stringLiteral: propertyKeys),
            DeclSyntax(stringLiteral: idProperty),
        ]
        if !relationQueryProperties.isEmpty {
            members.append(DeclSyntax(stringLiteral: relationQueryProperties))
        }
        members.append(DeclSyntax(stringLiteral: initializer))
        members.append(DeclSyntax(stringLiteral: encoder))
        members.append(contentsOf: fetchMethods)

        return members
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let properties = try resolvedProperties(of: declaration)
        guard !properties.isEmpty else { return [] }

        let isPublic = declaration.modifiers.contains { $0.name.text == "public" || $0.name.text == "open" }
        let access = isPublic ? "public " : ""
        let typeName = type.trimmedDescription

        let entries = properties
            .map { prop -> String in
                let keyPath = (prop.attribute == "NotionRelation" && prop.relatedType != nil) ? "_\(prop.identifier)" : prop.identifier
                return "        \\\(typeName).\(keyPath): NotionField(name: \"\(prop.key)\", kind: .\(notionKind(for: prop.attribute)))"
            }
            .joined(separator: ",\n")
        let property = [
            "\(access)static var notionProperties: [PartialKeyPath<\(typeName)>: NotionField] {",
            "    [",
            entries,
            "    ]",
            "}",
        ].joined(separator: "\n")

        let extensionSource = """
        extension \(typeName): NotionPage, Encodable {
        \(property)
        }
        """
        return [DeclSyntax(stringLiteral: extensionSource).cast(ExtensionDeclSyntax.self)]
    }
}

/// One `@Notion*`-annotated stored property as written, before the concrete
/// decoder is resolved from its declared type.
private struct ScannedProperty {
    let identifier: String
    let rawAttribute: String
    let key: String
    let type: TypeSyntax?
    /// For `@NotionRelationQuery`, the element type of the array (e.g. "Song" from `[Song]`).
    let relatedType: String?
}

/// Scans a `@NotionPage` type for its `@Notion*`-annotated stored properties.
/// Consumed by `resolvedProperties(of:)`, which is shared by the member
/// expansion and the extension expansion so both agree on which properties are
/// Notion-backed.
private func scannedProperties(of declaration: some DeclGroupSyntax) -> [ScannedProperty] {
    var scanned: [ScannedProperty] = []
    for member in declaration.memberBlock.members {
        guard
            let varDecl = member.decl.as(VariableDeclSyntax.self),
            let binding = varDecl.bindings.first,
            let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
        else {
            continue
        }
        let notionAttribute = varDecl.attributes
            .compactMap { element -> (String, String?)? in
                guard
                    let attribute = element.as(AttributeSyntax.self),
                    let name = attribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text,
                    name.hasPrefix("Notion")
                else {
                    return nil
                }
                return (name, extractKey(from: attribute))
            }
            .first
        guard let (rawAttribute, key) = notionAttribute else { continue }
        
        // For @NotionRelationQuery, extract the element type from the array (e.g., [Song] -> "Song")
        var relatedType: String? = nil
        if rawAttribute == "NotionRelationQuery",
           let type = binding.typeAnnotation?.type {
            let inner = type.as(OptionalTypeSyntax.self)?.wrappedType ?? type
            if let array = inner.as(ArrayTypeSyntax.self),
               let element = array.element.as(IdentifierTypeSyntax.self) {
                relatedType = element.name.text
            }
        }
        
        scanned.append(ScannedProperty(
            identifier: identifier,
            rawAttribute: rawAttribute,
            key: key ?? identifier,
            type: binding.typeAnnotation?.type,
            relatedType: relatedType
        ))
    }
    return scanned
}

/// Resolves each scanned property's declared attribute to its concrete
/// `@Notion*` decoder, validating the declared type. Shared by the member
/// expansion (decoding) and the extension expansion (the key-path map), so
/// the decoder and the map always agree on which properties are Notion-backed.
private func resolvedProperties(of declaration: some DeclGroupSyntax) throws -> [NotionPropertyInfo] {
    var properties: [NotionPropertyInfo] = []
    for scanned in scannedProperties(of: declaration) {
        var attribute = scanned.rawAttribute
        if attribute == "NotionProperty" {
            guard let resolved = resolvedAttribute(for: scanned.type) else {
                throw NotionPropertyTypeError(description:
                    "`@NotionProperty` on '\(scanned.identifier)' has unsupported type '\(scanned.type?.trimmedDescription ?? "<none>")'. Supported: String, URL?, [URL], Date?, Range<Date>?, Bool, Double?. Use `@NotionTitle` for the title property and `@NotionRelationIDs` for relations.")
            }
            attribute = resolved
        } else if attribute == "NotionDateStart" {
            guard isOptionalDate(scanned.type) else {
                throw NotionPropertyTypeError(description:
                    "`@NotionDateStart` on '\(scanned.identifier)' requires an optional `Date?` property, got '\(scanned.type?.trimmedDescription ?? "<none>")'.")
            }
        } else if attribute == "NotionRelationIDs" {
            guard arrayElementName(scanned.type) == "UUID" else {
                throw NotionPropertyTypeError(description:
                    "`@NotionRelationIDs` on '\(scanned.identifier)' requires a `[UUID]` property, got '\(scanned.type?.trimmedDescription ?? "<none>")'.")
            }
        } else if attribute == "NotionRelation" {
            // @NotionRelation accepts any array type; decoding/encoding uses Relation type
        } else if attribute == "NotionRelationQuery" {
            // @NotionRelationQuery requires an array of a @NotionPage type, e.g. [Song]
            guard scanned.relatedType != nil else {
                throw NotionPropertyTypeError(description:
                    "`@NotionRelationQuery` on '\(scanned.identifier)' requires an array of a @NotionPage type (e.g., [Song]), got '\(scanned.type?.trimmedDescription ?? "<none>")'.")
            }
            // Treat as NotionRelation for decoding/encoding (relation IDs)
            attribute = "NotionRelation"
        } else if attribute == "NotionCheckbox" {
            guard isBool(scanned.type) else {
                throw NotionPropertyTypeError(description:
                    "`@NotionCheckbox` on '\(scanned.identifier)' requires a `Bool` property, got '\(scanned.type?.trimmedDescription ?? "<none>")'.")
            }
        } else if attribute == "NotionNumber" {
            guard isOptionalDouble(scanned.type) else {
                throw NotionPropertyTypeError(description:
                    "`@NotionNumber` on '\(scanned.identifier)' requires an optional `Double?` property, got '\(scanned.type?.trimmedDescription ?? "<none>")'.")
            }
        }
        properties.append(NotionPropertyInfo(
            identifier: scanned.identifier,
            attribute: attribute,
            key: scanned.key,
            isOptional: scanned.type?.is(OptionalTypeSyntax.self) ?? false,
            relatedType: scanned.relatedType
        ))
    }
    return properties
}

/// `true` when the declared type is an optional `Date?`. Qualified types such
/// as `Foundation.Date?` are not recognized.
private func isOptionalDate(_ type: TypeSyntax?) -> Bool {
    guard let optional = type?.as(OptionalTypeSyntax.self) else { return false }
    return optional.wrappedType.as(IdentifierTypeSyntax.self)?.name.text == "Date"
}

/// `true` when the declared type is a non-optional `Bool`.
private func isBool(_ type: TypeSyntax?) -> Bool {
    type?.as(IdentifierTypeSyntax.self)?.name.text == "Bool"
}

/// `true` when the declared type is an optional `Double?`.
private func isOptionalDouble(_ type: TypeSyntax?) -> Bool {
    guard let optional = type?.as(OptionalTypeSyntax.self) else { return false }
    return optional.wrappedType.as(IdentifierTypeSyntax.self)?.name.text == "Double"
}

/// The element identifier of an array type, unwrapping one level of optional
/// (`[UUID]` -> `UUID`). `nil` for non-array types.
private func arrayElementName(_ type: TypeSyntax?) -> String? {
    guard let type else { return nil }
    let inner = type.as(OptionalTypeSyntax.self)?.wrappedType ?? type
    return inner.as(ArrayTypeSyntax.self)?.element.as(IdentifierTypeSyntax.self)?.name.text
}

/// Maps a declared property type to the concrete `@Notion*` decoder used by
/// `@NotionProperty`, or `nil` when the type is not supported.
private func resolvedAttribute(for type: TypeSyntax?) -> String? {
    guard let type else { return nil }

    let isOptional = type.is(OptionalTypeSyntax.self)
    let inner = type.as(OptionalTypeSyntax.self)?.wrappedType ?? type

    if let identifier = inner.as(IdentifierTypeSyntax.self) {
        switch identifier.name.text {
        case "String":
            return "NotionRichText"
        case "URL":
            return isOptional ? "NotionFile" : nil
        case "Date":
            return isOptional ? "NotionDateStart" : nil
        case "Bool":
            return isOptional ? nil : "NotionCheckbox"
        case "Double":
            return isOptional ? "NotionNumber" : nil
        case "Range":
            guard isOptional,
                  let argument = identifier.genericArgumentClause?.arguments.first,
                  argument.argument.as(IdentifierTypeSyntax.self)?.name.text == "Date"
            else { return nil }
            return "NotionDateRange"
        default:
            return nil
        }
    }

    if let array = inner.as(ArrayTypeSyntax.self),
       array.element.as(IdentifierTypeSyntax.self)?.name.text == "URL" {
        return "NotionFiles"
    }

    return nil
}

/// The `NotionField.Kind` for a resolved `@Notion*` attribute.
private func notionKind(for attribute: String) -> String {
    switch attribute {
    case "NotionTitle": return "title"
    case "NotionRichText": return "richText"
    case "NotionFile": return "file"
    case "NotionFiles": return "files"
    case "NotionDateStart": return "date"
    case "NotionDateRange": return "dateRange"
    case "NotionRelationIDs": return "relation"
    case "NotionRelation": return "relation"
    case "NotionCheckbox": return "checkbox"
    case "NotionNumber": return "number"
    default: return "richText"
    }
}

/// Builds the `self.<identifier> = ...` line that decodes one Notion property
/// using the shared value types from the `SwiftNotion` library.
private func decodeLine(for attribute: String, identifier: String) -> String? {
    switch attribute {
    case "NotionTitle":
        return "self.\(identifier) = (try? properties.decode(NotionDecoding.Title.self, forKey: .\(identifier)))?.title.first?.plainText ?? \"\""
    case "NotionRichText":
        return "self.\(identifier) = (try? properties.decode(NotionDecoding.RichText.self, forKey: .\(identifier)))?.richText.first?.plainText ?? \"\""
    case "NotionFile":
        return "self.\(identifier) = (try? properties.decode(NotionDecoding.Files.self, forKey: .\(identifier)))?.files.compactMap { $0.file?.url }.first.flatMap(URL.init(string:))"
    case "NotionFiles":
        return "self.\(identifier) = (try? properties.decode(NotionDecoding.Files.self, forKey: .\(identifier)))?.files.compactMap { $0.file?.url }.compactMap(URL.init(string:)) ?? []"
    case "NotionDateStart":
        return "self.\(identifier) = (try? properties.decode(NotionDecoding.DateValue.self, forKey: .\(identifier)))?.date?.start.flatMap(NotionDecoding.date(from:))"
    case "NotionDateRange":
        return "self.\(identifier) = (try? properties.decode(NotionDecoding.DateValue.self, forKey: .\(identifier)))?.date.flatMap(NotionDecoding.range(from:))"
    case "NotionRelationIDs":
        return "self.\(identifier) = (try? properties.decode(NotionDecoding.Relation.self, forKey: .\(identifier)))?.relation.compactMap { UUID(uuidString: $0.id) } ?? []"
    case "NotionRelation":
        return "self.\(identifier) = (try? properties.decode(NotionDecoding.Relation.self, forKey: .\(identifier)))?.relation.compactMap { UUID(uuidString: $0.id) } ?? []"
    case "NotionCheckbox":
        return "self.\(identifier) = (try? properties.decode(NotionDecoding.Checkbox.self, forKey: .\(identifier)))?.checkbox ?? false"
    case "NotionNumber":
        return "self.\(identifier) = (try? properties.decode(NotionDecoding.NumberValue.self, forKey: .\(identifier)))?.number"
    default:
        return nil
    }
}

/// Builds the `try properties.<function>(...)` line that encodes one Notion
/// property. `@NotionPage` synthesizes an `Encodable` whose output is the
/// Notion write shape of a Create/Update page request: each declared value is
/// wrapped in the matching `NotionEncoding` box (title/rich_text/files/date/
/// relation/checkbox/number). Optional properties use `encodeIfPresent`, so
/// `nil` omits the key and leaves the field untouched on update.
private func encodeLine(for property: NotionPropertyInfo) -> String {
    let function = property.isOptional ? "encodeIfPresent" : "encode"
    return "try properties.\(function)(\(encodedValueExpression(for: property)), forKey: .\(property.identifier))"
}

/// The value expression passed to `encode`/`encodeIfPresent`: the declared
/// property wrapped in the `NotionEncoding` box for its attribute. Optional
/// kinds map to their box (`Optional<Box>`), preserving optionality for
/// `encodeIfPresent`.
private func encodedValueExpression(for property: NotionPropertyInfo) -> String {
    let id = "self.\(property.identifier)"
    switch property.attribute {
    case "NotionTitle":
        return "NotionEncoding.Title(content: \(id))"
    case "NotionRichText":
        return "NotionEncoding.RichText(content: \(id))"
    case "NotionFile":
        return "\(id).map { NotionEncoding.File(url: $0) }"
    case "NotionFiles":
        return "NotionEncoding.Files(urls: \(id))"
    case "NotionDateStart":
        return "\(id).map { NotionEncoding.DateValue(start: $0) }"
    case "NotionDateRange":
        return "\(id).map { NotionEncoding.DateValue(start: $0.lowerBound, end: $0.upperBound) }"
    case "NotionRelationIDs":
        return "NotionEncoding.Relation(ids: \(id))"
    case "NotionRelation":
        return "NotionEncoding.Relation(ids: \(id))"
    case "NotionCheckbox":
        return "NotionEncoding.Checkbox(value: \(id))"
    case "NotionNumber":
        return "\(id).map { NotionEncoding.Number(value: $0) }"
    default:
        return id
    }
}

func extractKey(from node: AttributeSyntax) -> String? {
    guard let args = node.arguments?.as(LabeledExprListSyntax.self),
          let firstArg = args.first,
          let string = firstArg.expression.as(StringLiteralExprSyntax.self),
          let first = string.segments.first
    else { return nil }

    switch first {
    case .stringSegment(let segment):
        return segment.content.text
    default:
        return nil
    }
}

/// Generates `_fetchRelations(using:)` and per-property fetch helpers for `@NotionRelationQuery`.
private func generateFetchMethods(for properties: [NotionPropertyInfo], access: String) -> [DeclSyntax] {
    let relationQueries = properties.filter { $0.attribute == "NotionRelation" && $0.relatedType != nil }
    guard !relationQueries.isEmpty else { return [] }

    var methods: [String] = []

    // _fetchRelations(using:) - calls all per-property fetch helpers
    let fetchRelationsCalls = relationQueries
        .map { prop in
            let capitalized = prop.identifier.prefix(1).uppercased() + prop.identifier.dropFirst()
            return "        try await _fetch\(capitalized)(using: client)"
        }
        .joined(separator: "\n")

    let fetchRelationsMethod = """
    \(access)mutating func _fetchRelations(using client: NotionClient) async throws {
    \(fetchRelationsCalls)
    }
    """
    methods.append(fetchRelationsMethod)

    // Per-property fetch helpers
    for prop in relationQueries {
        let capitalized = prop.identifier.prefix(1).uppercased() + prop.identifier.dropFirst()
        let relatedType = prop.relatedType!
        let fetchMethod = """
    \(access)private mutating func _fetch\(capitalized)(using client: NotionClient) async throws {
        self.\(prop.identifier) = try await withThrowingTaskGroup(of: \(relatedType).self) { group in
            for id in _\(prop.identifier) {
                group.addTask {
                    try await client.fetchPage(pageID: id.uuidString.lowercased())
                }
            }
            var results: [\(relatedType)] = []
            for try await page in group { results.append(page) }
            return results
        }
    }
    """
        methods.append(fetchMethod)
    }

    return methods.map { DeclSyntax(stringLiteral: $0) }
}
