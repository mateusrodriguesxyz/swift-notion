//
//  NotionPropertyInfo.swift
//  NotionMacros
//
//  Created by Mateus Rodrigues on 11/10/26.
//
import SwiftSyntax

/// One `@Notion*`-annotated stored property of a `@NotionPage` type.
struct NotionPropertyInfo {
    let identifier: String
    let attribute: String
    let key: String
}
