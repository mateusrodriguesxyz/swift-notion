import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct NotionMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        NotionPageMacro.self,
        NotionTitleMacro.self,
        NotionRichTextMacro.self,
        NotionFileMacro.self,
        NotionFilesMacro.self,
        NotionDateStartMacro.self,
        NotionDateRangeMacro.self,
        NotionRelationIDsMacro.self,
        NotionPropertyMacro.self,
    ]
}