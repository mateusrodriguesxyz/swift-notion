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

        let decodeLines = properties
            .compactMap { decodeLine(for: $0.attribute, identifier: $0.identifier) }
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

        let initializer = """
        \(access)init(from decoder: Decoder) throws {
            let root = try decoder.container(keyedBy: CodingKeys.self)
            self.id = (try? root.decode(String.self, forKey: .id)).flatMap(UUID.init(uuidString:)) ?? UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
            let properties = try root.nestedContainer(keyedBy: PropertyKeys.self, forKey: .properties)
            \(decodeLines)
        }
        """

        let encodeLines = properties
            .map { encodeLine(for: $0) }
            .joined(separator: "\n    ")

        // Emitted as a member, not through the extension expansion, so it is
        // covered by `names: arbitrary`. The extension expansion declares the
        // `Encodable` conformance that this member satisfies.
        let encoder = """
        \(access)func encode(to encoder: any Encoder) throws {
            var root = encoder.container(keyedBy: CodingKeys.self)
            try root.encode(id, forKey: .id)
            var properties = root.nestedContainer(keyedBy: PropertyKeys.self, forKey: .properties)
            \(encodeLines)
        }
        """

        return [
            DeclSyntax(stringLiteral: codingKeys),
            DeclSyntax(stringLiteral: propertyKeys),
            DeclSyntax(stringLiteral: idProperty),
            DeclSyntax(stringLiteral: initializer),
            DeclSyntax(stringLiteral: encoder),
        ]
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
            .map { "        \\\(typeName).\($0.identifier): NotionMacros.NotionField(name: \"\($0.key)\", kind: .\(notionKind(for: $0.attribute)))" }
            .joined(separator: ",\n")
        let property = [
            "\(access)static var notionProperties: [PartialKeyPath<\(typeName)>: NotionMacros.NotionField] {",
            "    [",
            entries,
            "    ]",
            "}",
        ].joined(separator: "\n")

        let extensionSource = """
        extension \(typeName): NotionMacros.NotionPage, Encodable {
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
        scanned.append(ScannedProperty(
            identifier: identifier,
            rawAttribute: rawAttribute,
            key: key ?? identifier,
            type: binding.typeAnnotation?.type
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
            isOptional: scanned.type?.is(OptionalTypeSyntax.self) ?? false
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
    case "NotionCheckbox": return "checkbox"
    case "NotionNumber": return "number"
    default: return "richText"
    }
}

/// Builds the `self.<identifier> = ...` line that decodes one Notion property
/// using the shared value types from the `NotionMacros` library.
private func decodeLine(for attribute: String, identifier: String) -> String? {
    switch attribute {
    case "NotionTitle":
        return "self.\(identifier) = (try? properties.decode(NotionMacros.NotionDecoding.Title.self, forKey: .\(identifier)))?.title.first?.plainText ?? \"\""
    case "NotionRichText":
        return "self.\(identifier) = (try? properties.decode(NotionMacros.NotionDecoding.RichText.self, forKey: .\(identifier)))?.richText.first?.plainText ?? \"\""
    case "NotionFile":
        return "self.\(identifier) = (try? properties.decode(NotionMacros.NotionDecoding.Files.self, forKey: .\(identifier)))?.files.compactMap { $0.file?.url }.first.flatMap(URL.init(string:))"
    case "NotionFiles":
        return "self.\(identifier) = (try? properties.decode(NotionMacros.NotionDecoding.Files.self, forKey: .\(identifier)))?.files.compactMap { $0.file?.url }.compactMap(URL.init(string:)) ?? []"
    case "NotionDateStart":
        return "self.\(identifier) = (try? properties.decode(NotionMacros.NotionDecoding.DateValue.self, forKey: .\(identifier)))?.date?.start.flatMap(NotionMacros.NotionDecoding.date(from:))"
    case "NotionDateRange":
        return "self.\(identifier) = (try? properties.decode(NotionMacros.NotionDecoding.DateValue.self, forKey: .\(identifier)))?.date.flatMap(NotionMacros.NotionDecoding.range(from:))"
    case "NotionRelationIDs":
        return "self.\(identifier) = (try? properties.decode(NotionMacros.NotionDecoding.Relation.self, forKey: .\(identifier)))?.relation.compactMap { UUID(uuidString: $0.id) } ?? []"
    case "NotionCheckbox":
        return "self.\(identifier) = (try? properties.decode(NotionMacros.NotionDecoding.Checkbox.self, forKey: .\(identifier)))?.checkbox ?? false"
    case "NotionNumber":
        return "self.\(identifier) = (try? properties.decode(NotionMacros.NotionDecoding.NumberValue.self, forKey: .\(identifier)))?.number"
    default:
        return nil
    }
}

/// Builds the `try properties.<function>(...)` line that encodes one Notion
/// property as its Swift value. `@NotionPage` synthesizes a minimal `Encodable`
/// conformance: property values (including `URL`/`[URL]`) encode through their
/// own `Codable` conformances, not Notion write shapes.
private func encodeLine(for property: NotionPropertyInfo) -> String {
    let function = property.isOptional ? "encodeIfPresent" : "encode"
    return "try properties.\(function)(self.\(property.identifier), forKey: .\(property.identifier))"
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
