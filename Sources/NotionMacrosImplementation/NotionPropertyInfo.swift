//
//  NotionPropertyInfo.swift
//  SwiftNotion
//
//  Created by Mateus Rodrigues on 11/10/26.
//
import SwiftSyntax

/// One `@Notion*`-annotated stored property of a `@NotionPage` type.
struct NotionPropertyInfo {
    let identifier: String
    let attribute: String
    let key: String
    /// `true` when the declared property type is optional, so the generated
    /// encoder picks `encodeIfPresent` instead of `encode`.
    let isOptional: Bool
    /// For `@NotionRelationQuery`, the element type of the array (e.g. "Song" from `[Song]`).
    let relatedType: String?
}
