//
//  PredicateFilter.swift
//  NotionMacros
//

import Foundation

/// Errors thrown when a `Predicate` cannot be expressed as a `NotionFilter`.
public enum NotionFilterConversionError: Error, Equatable, Sendable {
    /// The root expression is not a supported node (e.g. `Negation` until increment 6).
    case unsupportedRoot(String)
    /// An `Equal` (or later `Comparison`) references a KeyPath not registered in
    /// the type's `notionProperties`, or whose kind is not convertible yet.
    case unsupportedField(String)
    /// The two sides of a comparison cannot be combined into a filter (e.g. two
    /// bare string literals, or a field compared to a non-string).
    case unsupportedOperands(String)
}

/// A node that composes to a complete `NotionFilter` (root expressions: `Equal`,
/// `SequenceContains`, and `Negation` of a negatable leaf).
protocol NotionFilterExpression {
    func notionFilter() throws -> NotionFilter
}

/// A node whose filter has a direct negated counterpart in Notion (text
/// `does_not_equal`, relation `does_not_contain`). Notion has no generic NOT, so
/// only leaves with such a counterpart can be negated.
protocol NotionNegatableExpression {
    func negatedFilter() throws -> NotionFilter
}

/// A root expression that is a bare checkbox property (`$0.published`) rather
/// than a comparison. It keeps its own protocol because `KeyPath` already
/// conforms to `NotionFilterExpression` for the files `isEmpty` shape and Swift
/// allows one conditional conformance per type and protocol.
protocol NotionBareCheckboxExpression {
    func checkboxFilter(negated: Bool) throws -> NotionFilter
}

/// A node that resolves to one side of a comparison (`Value`, `KeyPath`).
protocol NotionFilterOperandExpression {
    func operand() throws -> FilterOperand
}

/// One side of a comparison as resolved by the walker. Kept internal; grows in
/// later increments (`date(Date)`, `number(Double)`).
enum FilterOperand {
    case field(NotionField)
    case string(String)
    case uuid(UUID)
    case bool(Bool)
    case null
}

/// A literal type that can sit on one side of a comparison (`PredicateExpressions.Value`).
/// Add a conformance here to support a new operand type; `Value` conforms once,
/// keyed on this protocol, so several operand types need no extra conformances.
protocol NotionFilterOperand {
    func filterOperand() -> FilterOperand
}

extension String: NotionFilterOperand {
    func filterOperand() -> FilterOperand { .string(self) }
}

extension UUID: NotionFilterOperand {
    func filterOperand() -> FilterOperand { .uuid(self) }
}

extension Bool: NotionFilterOperand {
    func filterOperand() -> FilterOperand { .bool(self) }
}

@available(macOS 14.0, iOS 17.0, *)
extension PredicateExpressions.Value: NotionFilterOperandExpression where Output: NotionFilterOperand {
    func operand() throws -> FilterOperand { value.filterOperand() }
}

/// `nil` on one side of a comparison (`$0.photoURL == nil`). Resolves to
/// `FilterOperand.null`; only the `.file` kind maps it to a `files` filter.
@available(macOS 14.0, iOS 17.0, *)
extension PredicateExpressions.NilLiteral: NotionFilterOperandExpression {
    func operand() throws -> FilterOperand { .null }
}

@available(macOS 14.0, iOS 17.0, *)
extension PredicateExpressions.KeyPath: NotionFilterOperandExpression where Root.Output: NotionPage {
    func operand() throws -> FilterOperand {
        if let field = Root.Output.notionProperty(for: keyPath) {
            return .field(field)
        }
        // Captured value key path (e.g. `artist.id`): evaluate it to a literal. Only
        // reachable for a `Value` root, which Foundation already required to be
        // `Codable`; a `Variable` root throws here (no bindings) and is reported below.
        if let value = try? evaluate(PredicateBindings()),
           let operand = value as? any NotionFilterOperand {
            return operand.filterOperand()
        }
        throw NotionFilterConversionError.unsupportedField("\(keyPath)")
    }
}

/// Resolves the two sides of an `Equal`/`NotEqual` comparison into a filter.
/// Shared by both nodes so `a != b` is exactly the negation of `a == b`.
@available(macOS 14.0, iOS 17.0, *)
private func notionComparisonFilter<L: NotionFilterOperandExpression, R: NotionFilterOperandExpression>(
    _ lhs: L,
    _ rhs: R,
    negated: Bool
) throws -> NotionFilter {
    let left = try lhs.operand()
    let right = try rhs.operand()
    switch (left, right) {
    case (.field(let field), .string(let value)), (.string(let value), .field(let field)):
        let condition: TextCondition = negated ? .doesNotEqual(value) : .equals(value)
        switch field.kind {
        case .title:
            return .title(field.name, condition)
        case .richText:
            return .richText(field.name, condition)
        default:
            throw NotionFilterConversionError.unsupportedField(field.name)
        }
    case (.field(let field), .bool(let value)), (.bool(let value), .field(let field)):
        guard field.kind == .checkbox else {
            throw NotionFilterConversionError.unsupportedField(field.name)
        }
        // Notion's checkbox condition has only `equals`; its exact negation is
        // the opposite value, so `!=` and `!` need no `does_not_equal` shape.
        return .checkbox(field.name, equals: negated ? !value : value)
    case (.field(let field), .null), (.null, .field(let field)):
        guard field.kind == .file else {
            throw NotionFilterConversionError.unsupportedField(field.name)
        }
        return .files(field.name, negated ? .isNotEmpty : .isEmpty)
    default:
        throw NotionFilterConversionError.unsupportedOperands("\(left) vs \(right)")
    }
}

/// `$0.field == value` -> the field's equality condition, or its negated
/// counterpart (`!($0.field == value)`). `== nil` on a `.file` field maps to
/// files `is_empty`. A `Bool` value maps a `.checkbox` field to
/// `equals: <value>`, or `equals: !value` when negated.
@available(macOS 14.0, iOS 17.0, *)
extension PredicateExpressions.Equal: NotionFilterExpression, NotionNegatableExpression
where LHS: NotionFilterOperandExpression, RHS: NotionFilterOperandExpression {
    func notionFilter() throws -> NotionFilter { try notionComparisonFilter(lhs, rhs, negated: false) }
    func negatedFilter() throws -> NotionFilter { try notionComparisonFilter(lhs, rhs, negated: true) }
}

/// `$0.field != value` -> the negation of the equivalent `Equal`. `!= nil` on a
/// `.file` field maps to files `is_not_empty`. (`!=` is a distinct node, not a
/// `Negation` of `Equal`.)
@available(macOS 14.0, iOS 17.0, *)
extension PredicateExpressions.NotEqual: NotionFilterExpression, NotionNegatableExpression
where LHS: NotionFilterOperandExpression, RHS: NotionFilterOperandExpression {
    func notionFilter() throws -> NotionFilter { try notionComparisonFilter(lhs, rhs, negated: true) }
    func negatedFilter() throws -> NotionFilter { try notionComparisonFilter(lhs, rhs, negated: false) }
}

/// `$0.relationIDs.contains(id)` -> a `relation` `contains` filter (or
/// `does_not_contain` when negated). The `SequenceContains` node stores its sides
/// as `sequence` and `element`.
@available(macOS 14.0, iOS 17.0, *)
extension PredicateExpressions.SequenceContains: NotionFilterExpression, NotionNegatableExpression
where LHS: NotionFilterOperandExpression, RHS: NotionFilterOperandExpression {
    func notionFilter() throws -> NotionFilter { try filter(negated: false) }
    func negatedFilter() throws -> NotionFilter { try filter(negated: true) }

    private func filter(negated: Bool) throws -> NotionFilter {
        let lhs = try sequence.operand()
        let rhs = try element.operand()
        switch (lhs, rhs) {
        case (.field(let field), .uuid(let id)):
            guard field.kind == .relation else {
                throw NotionFilterConversionError.unsupportedField(field.name)
            }
            return .relation(field.name, negated ? .doesNotContain(id) : .contains(id))
        default:
            throw NotionFilterConversionError.unsupportedOperands("\(lhs) vs \(rhs)")
        }
    }
}

/// `$0.text.contains("x")` -> `contains` on the title or rich text property (or
/// `does_not_contain` when negated). `String.contains(_:)` builds
/// `CollectionContainsCollection`, distinct from the `SequenceContains` built by
/// `relationIDs.contains(id)`. Its operands are labelled `base`/`other`.
@available(macOS 14.0, iOS 17.0, *)
extension PredicateExpressions.CollectionContainsCollection: NotionFilterExpression, NotionNegatableExpression
where Base: NotionFilterOperandExpression, Other: NotionFilterOperandExpression {
    func notionFilter() throws -> NotionFilter { try filter(negated: false) }
    func negatedFilter() throws -> NotionFilter { try filter(negated: true) }

    private func filter(negated: Bool) throws -> NotionFilter {
        let lhs = try base.operand()
        let rhs = try other.operand()
        switch (lhs, rhs) {
        case (.field(let field), .string(let value)):
            let condition: TextCondition = negated ? .doesNotContain(value) : .contains(value)
            switch field.kind {
            case .title:
                return .title(field.name, condition)
            case .richText:
                return .richText(field.name, condition)
            default:
                throw NotionFilterConversionError.unsupportedField(field.name)
            }
        default:
            throw NotionFilterConversionError.unsupportedOperands("\(lhs) vs \(rhs)")
        }
    }
}

/// `$0.text.starts(with: "x")` -> `starts_with` on the title or rich text
/// property. `String.starts(with:)` builds `SequenceStartsWith`, whose operands
/// are labelled `base`/`prefix`. Notion has no "does not start with", so this is
/// not `NotionNegatableExpression`: `!$0.text.starts(with:)` fails the root cast.
@available(macOS 14.0, iOS 17.0, *)
extension PredicateExpressions.SequenceStartsWith: NotionFilterExpression
where Base: NotionFilterOperandExpression, Prefix: NotionFilterOperandExpression {
    func notionFilter() throws -> NotionFilter {
        let lhs = try base.operand()
        let rhs = try prefix.operand()
        switch (lhs, rhs) {
        case (.field(let field), .string(let value)):
            switch field.kind {
            case .title:
                return .title(field.name, .startsWith(value))
            case .richText:
                return .richText(field.name, .startsWith(value))
            default:
                throw NotionFilterConversionError.unsupportedField(field.name)
            }
        default:
            throw NotionFilterConversionError.unsupportedOperands("\(lhs) vs \(rhs)")
        }
    }
}

/// `$0.files.isEmpty` -> `files` `is_empty` (or `is_not_empty` when negated).
/// The `isEmpty` key path is resolved against the concrete `[URL]` files shape,
/// not `Collection` (a `Collection`-constrained comparison fails at runtime).
@available(macOS 14.0, iOS 17.0, *)
extension PredicateExpressions.KeyPath: NotionFilterExpression, NotionNegatableExpression
where Root: NotionFilterOperandExpression, Root.Output == [URL], Output == Bool {
    func notionFilter() throws -> NotionFilter { try filter(negated: false) }
    func negatedFilter() throws -> NotionFilter { try filter(negated: true) }

    private func filter(negated: Bool) throws -> NotionFilter {
        guard case .field(let field) = try root.operand() else {
            throw NotionFilterConversionError.unsupportedOperands("\(keyPath)")
        }
        guard field.kind == .files else {
            throw NotionFilterConversionError.unsupportedField(field.name)
        }
        guard keyPath == \.isEmpty else {
            throw NotionFilterConversionError.unsupportedField("\(keyPath)")
        }
        return .files(field.name, negated ? .isNotEmpty : .isEmpty)
    }
}

/// `$0.done` (a bare checkbox property) -> `checkbox` `equals: true`, or
/// `equals: false` when negated (`!$0.done`). The key path hangs off the page type
/// directly, so it is keyed on `Root.Output: NotionPage` rather than on an operand
/// expression.
@available(macOS 14.0, iOS 17.0, *)
extension PredicateExpressions.KeyPath: NotionBareCheckboxExpression
where Root.Output: NotionPage, Output == Bool {
    func checkboxFilter(negated: Bool) throws -> NotionFilter {
        guard let field = Root.Output.notionProperty(for: keyPath) else {
            throw NotionFilterConversionError.unsupportedField("\(keyPath)")
        }
        guard field.kind == .checkbox else {
            throw NotionFilterConversionError.unsupportedField(field.name)
        }
        return .checkbox(field.name, equals: !negated)
    }
}

/// `!$0.done` -> checkbox `equals: false`.
@available(macOS 14.0, iOS 17.0, *)
extension PredicateExpressions.Negation: NotionBareCheckboxExpression
where Wrapped: NotionBareCheckboxExpression {
    func checkboxFilter(negated: Bool) throws -> NotionFilter {
        try wrapped.checkboxFilter(negated: !negated)
    }
}

/// `!<leaf>` -> the leaf's negated counterpart. Only leaves that are
/// `NotionNegatableExpression` convert; anything else fails the root cast.
@available(macOS 14.0, iOS 17.0, *)
extension PredicateExpressions.Negation: NotionFilterExpression
where Wrapped: NotionNegatableExpression {
    func notionFilter() throws -> NotionFilter { try wrapped.negatedFilter() }
}

/// Converts a `Predicate` over a `NotionPage` type into a `NotionFilter` by
/// tree-walking its expression. Supported root nodes are `Equal`/`NotEqual`
/// (title and rich text equality, checkbox equality, and `== nil`/`!= nil` on
/// files), `SequenceContains` (relation `contains`), `CollectionContainsCollection`
/// (title/rich text `contains`, e.g. `$0.bio.contains("x")`), `SequenceStartsWith`
/// (title/rich text `starts(with:)`), `KeyPath` (a bare checkbox property, e.g.
/// `$0.published` -> checkbox `equals: true`, and `$0.files.isEmpty` ->
/// files `is_empty`) and `Negation` of any negatable leaf (text `does_not_equal`,
/// `does_not_contain`, relation `does_not_contain`, files `is_not_empty`, checkbox
/// `equals: <opposite>`); every other shape throws
/// `NotionFilterConversionError`. `starts(with:)` is not negatable, since Notion
/// has no "does not start with".
@available(macOS 14.0, iOS 17.0, *)
public func notionFilter<Root: NotionPage>(_ predicate: Predicate<Root>) throws -> NotionFilter {
    if let checkbox = predicate.expression as? any NotionBareCheckboxExpression {
        return try checkbox.checkboxFilter(negated: false)
    }
    guard let expression = predicate.expression as? any NotionFilterExpression else {
        throw NotionFilterConversionError.unsupportedRoot("\(predicate.expression)")
    }
    return try expression.notionFilter()
}

public extension NotionFilter {
    /// Builds a filter from a `Predicate` over a `NotionPage` type. Factory form
    /// of `notionFilter(_:)`, usable in leading-dot position:
    /// `fetchArts(filter: .predicate(#Predicate<ArtDTO> { $0.artistIDs.contains(id) }))`.
    @available(macOS 14.0, iOS 17.0, *)
    static func predicate<Root: NotionPage>(_ predicate: Predicate<Root>) throws -> NotionFilter {
        try notionFilter(predicate)
    }
}
