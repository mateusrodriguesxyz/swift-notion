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

@available(macOS 14.0, iOS 17.0, *)
extension PredicateExpressions.Value: NotionFilterOperandExpression where Output: NotionFilterOperand {
    func operand() throws -> FilterOperand { value.filterOperand() }
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

@available(macOS 14.0, iOS 17.0, *)
extension PredicateExpressions.Equal: NotionFilterExpression, NotionNegatableExpression
where LHS: NotionFilterOperandExpression, RHS: NotionFilterOperandExpression {
    func notionFilter() throws -> NotionFilter { try filter(negated: false) }
    func negatedFilter() throws -> NotionFilter { try filter(negated: true) }

    private func filter(negated: Bool) throws -> NotionFilter {
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
        default:
            throw NotionFilterConversionError.unsupportedOperands("\(left) vs \(right)")
        }
    }
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

/// `!<leaf>` -> the leaf's negated counterpart. Only leaves that are
/// `NotionNegatableExpression` convert; anything else fails the root cast.
@available(macOS 14.0, iOS 17.0, *)
extension PredicateExpressions.Negation: NotionFilterExpression
where Wrapped: NotionNegatableExpression {
    func notionFilter() throws -> NotionFilter { try wrapped.negatedFilter() }
}

/// Converts a `Predicate` over a `NotionPage` type into a `NotionFilter` by
/// tree-walking its expression. Supported root nodes are `Equal` (title and rich
/// text equality), `SequenceContains` (relation `contains`), `KeyPath`
/// (`$0.files.isEmpty` -> files `is_empty`) and `Negation` of any negatable leaf
/// (text `does_not_equal`, relation `does_not_contain`, files `is_not_empty`);
/// every other shape throws `NotionFilterConversionError`.
@available(macOS 14.0, iOS 17.0, *)
public func notionFilter<Root: NotionPage>(_ predicate: Predicate<Root>) throws -> NotionFilter {
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
