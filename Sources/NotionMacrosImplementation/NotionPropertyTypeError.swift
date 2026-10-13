//
//  NotionPropertyTypeError.swift
//  NotionMacros
//
//  Created by Mateus Rodrigues on 11/10/26.
//
import SwiftSyntax

/// Raised when a `@Notion*` property has a declared Swift type the macro cannot map.
struct NotionPropertyTypeError: Error, CustomStringConvertible {
    let description: String
}
