import SwiftSyntax
import SwiftSyntaxMacros

public struct NotionTitleMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] { [] }
}
public struct NotionRichTextMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] { [] }
}
public struct NotionFileMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] { [] }
}
public struct NotionFilesMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] { [] }
}
public struct NotionDateStartMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] { [] }
}
public struct NotionDateRangeMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] { [] }
}
public struct NotionRelationIDsMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] { [] }
}
public struct NotionCheckboxMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] { [] }
}
public struct NotionNumberMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] { [] }
}
public struct NotionSelectMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] { [] }
}
public struct NotionMultiSelectMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] { [] }
}
public struct NotionPropertyMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] { [] }
}
/// Emits a peer `_assertNotionRelation_<name>()` that calls `_assertNotionRelationProperty`
/// on the relation's element type. That call is constrained to `T: NotionPage`, so a
/// non-page element type is a compile error. `#sourceLocation` points the diagnostic
/// at the property declaration line instead of the macro expansion.
public struct NotionRelationPropertyMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        guard let variable = declaration.as(VariableDeclSyntax.self),
              let binding = variable.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
              let type = binding.typeAnnotation?.type
        else { return [] }

        let inner = type.as(OptionalTypeSyntax.self)?.wrappedType ?? type
        guard let element = inner.as(ArrayTypeSyntax.self)?.element else { return [] }

        let body: String
        if let location = context.location(of: node, at: .afterLeadingTrivia, filePathMode: .filePath) {
            body = """
            #sourceLocation(file: \(location.file.trimmedDescription), line: \(location.line.trimmedDescription))
                _assertNotionRelationProperty(\(element.trimmedDescription).self)
            #sourceLocation()
            """
        } else {
            body = "    _assertNotionRelationProperty(\(element.trimmedDescription).self)"
        }

        let source = """
        private func _assertNotionRelation_\(identifier)() {
        \(body)
        }
        """
        return [DeclSyntax("\(raw: source)")]
    }
}