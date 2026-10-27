//
//  PredicateFilterTests.swift
//  NotionMacrosTests
//
//  Every expected JSON body is taken from
//  https://developers.notion.com/reference/filter-data-source-entries, and the
//  property names match the examples on that page ("Task completed", "Done",
//  "Blueprint", "✔️ Task List", "Description").
//

import Foundation
import Notion
import Testing

/// Checkbox examples: "Task completed" and the "Done" leaf of the compound example.
@NotionPage
struct TaskDTO: Decodable {
    @NotionCheckbox("Task completed") var completed: Bool
    @NotionCheckbox("Done") var done: Bool
    @NotionRelationIDs("✔️ Task List") var taskList: [UUID]
}

/// The docs' files example uses a single-file property named "Blueprint".
@NotionPage
struct BlueprintDTO: Decodable {
    @NotionProperty("Blueprint") var blueprint: URL?
}

/// The same files property read as a multi-file value, used for `isEmpty`.
@NotionPage
struct BlueprintFilesDTO: Decodable {
    @NotionProperty("Blueprint") var blueprint: [URL]
}

/// The docs' rich text example property is "Description"; "Name" stands in for
/// a title, which accepts the same conditions.
@NotionPage
struct DescriptionDTO: Decodable {
    @NotionTitle("Name") var name: String
    @NotionProperty("Description") var description: String
}

/// Used to prove a captured DTO id key path resolves in a `#Predicate`.
@NotionPage
struct CapturedPageDTO: Decodable {
    @NotionTitle("Name") var name: String
}

/// A Bool property the macro does not register with a Notion field.
@NotionPage
struct UnregisteredBoolDTO: Decodable {
    @NotionTitle("Name") var name: String
    var flag: Bool = false
}

private let taskListID = UUID(uuidString: "0c1f7cb2-8090-4f18-924e-d92965055e32")!

private let capturedPageJSON = """
{
  "id": "0c1f7cb2-8090-4f18-924e-d92965055e32",
  "properties": {
    "Nome": { "type": "title", "title": [ { "plain_text": "Captured Page" } ] }
  }
}
""".data(using: .utf8)!

@Suite
struct PredicateFilterTests {
    // MARK: Checkbox

    @Test
    @available(macOS 14.0, *)
    func checkboxPredicatesMatchCheckboxDocExamples() {
        // Intro example and "Example checkbox filter object".
        expectFilter(
            #Predicate<TaskDTO> { $0.completed },
            docJSON: #"{"property":"Task completed","checkbox":{"equals":true}}"#
        )
        expectFilter(
            #Predicate<TaskDTO> { $0.completed == true },
            docJSON: #"{"property":"Task completed","checkbox":{"equals":true}}"#
        )
        // Checkbox table: `equals` example value `false`.
        expectFilter(
            #Predicate<TaskDTO> { $0.completed == false },
            docJSON: #"{"property":"Task completed","checkbox":{"equals":false}}"#
        )
        expectFilter(
            #Predicate<TaskDTO> { !$0.completed },
            docJSON: #"{"property":"Task completed","checkbox":{"equals":false}}"#
        )
        expectFilter(
            #Predicate<TaskDTO> { $0.completed != true },
            docJSON: #"{"property":"Task completed","checkbox":{"equals":false}}"#
        )
        // The "Done" leaf of the compound and/or example.
        expectFilter(
            #Predicate<TaskDTO> { $0.done },
            docJSON: #"{"property":"Done","checkbox":{"equals":true}}"#
        )
        expectFilter(
            #Predicate<TaskDTO> { !$0.done },
            docJSON: #"{"property":"Done","checkbox":{"equals":false}}"#
        )
    }

    // MARK: Files

    @Test
    @available(macOS 14.0, *)
    func filesPredicatesMatchFilesDocExamples() {
        // "Example files filter condition".
        expectFilter(
            #Predicate<BlueprintDTO> { $0.blueprint != nil },
            docJSON: #"{"property":"Blueprint","files":{"is_not_empty":true}}"#
        )
        // Files table: `is_empty`.
        expectFilter(
            #Predicate<BlueprintDTO> { $0.blueprint == nil },
            docJSON: #"{"property":"Blueprint","files":{"is_empty":true}}"#
        )
        expectFilter(
            #Predicate<BlueprintDTO> { !($0.blueprint == nil) },
            docJSON: #"{"property":"Blueprint","files":{"is_not_empty":true}}"#
        )
        expectFilter(
            #Predicate<BlueprintFilesDTO> { $0.blueprint.isEmpty },
            docJSON: #"{"property":"Blueprint","files":{"is_empty":true}}"#
        )
        expectFilter(
            #Predicate<BlueprintFilesDTO> { !$0.blueprint.isEmpty },
            docJSON: #"{"property":"Blueprint","files":{"is_not_empty":true}}"#
        )
    }

    // MARK: Relation

    @Test
    @available(macOS 14.0, *)
    func relationPredicatesMatchRelationDocExamples() {
        // The docs write the UUID undashed ("0c1f7cb280904f18924ed92965055e32");
        // RelationCondition always emits the dashed, lowercased form, which
        // names the same UUIDv4 and is accepted by Notion.
        expectFilter(
            #Predicate<TaskDTO> { $0.taskList.contains(taskListID) },
            docJSON: #"{"property":"✔️ Task List","relation":{"contains":"0c1f7cb2-8090-4f18-924e-d92965055e32"}}"#
        )
        expectFilter(
            #Predicate<TaskDTO> { !$0.taskList.contains(taskListID) },
            docJSON: #"{"property":"✔️ Task List","relation":{"does_not_contain":"0c1f7cb2-8090-4f18-924e-d92965055e32"}}"#
        )
    }

    @Test
    @available(macOS 14.0, *)
    func relationPredicateResolvesCapturedPageID() throws {
        let captured = try JSONDecoder().decode(CapturedPageDTO.self, from: capturedPageJSON)
        #expect(captured.id == taskListID, "captured page decodes its id")
        expectFilter(
            #Predicate<TaskDTO> { $0.taskList.contains(captured.id) },
            docJSON: #"{"property":"✔️ Task List","relation":{"contains":"0c1f7cb2-8090-4f18-924e-d92965055e32"}}"#
        )
        expectFilter(
            #Predicate<TaskDTO> { !$0.taskList.contains(captured.id) },
            docJSON: #"{"property":"✔️ Task List","relation":{"does_not_contain":"0c1f7cb2-8090-4f18-924e-d92965055e32"}}"#
        )
    }

    // MARK: Rich text

    @Test
    @available(macOS 14.0, *)
    func richTextPredicatesMatchRichTextDocExamples() {
        // "Example rich text filter condition".
        expectFilter(
            #Predicate<DescriptionDTO> { $0.description.contains("cross-team") },
            docJSON: #"{"property":"Description","rich_text":{"contains":"cross-team"}}"#
        )
        // Rich text table examples.
        expectFilter(
            #Predicate<DescriptionDTO> { !$0.description.contains("cross-team") },
            docJSON: #"{"property":"Description","rich_text":{"does_not_contain":"cross-team"}}"#
        )
        expectFilter(
            #Predicate<DescriptionDTO> { $0.description == "Moved to Q2" },
            docJSON: #"{"property":"Description","rich_text":{"equals":"Moved to Q2"}}"#
        )
        expectFilter(
            #Predicate<DescriptionDTO> { $0.description != "Moved to Q2" },
            docJSON: #"{"property":"Description","rich_text":{"does_not_equal":"Moved to Q2"}}"#
        )
        expectFilter(
            #Predicate<DescriptionDTO> { $0.description.starts(with: "Moved") },
            docJSON: #"{"property":"Description","rich_text":{"starts_with":"Moved"}}"#
        )
    }

    // MARK: Title

    @Test
    @available(macOS 14.0, *)
    func titlePredicatesReuseRichTextDocConditions() {
        // The page documents these conditions for rich text; Notion title
        // filters accept the same set, so the expected bodies only swap the
        // property-type key.
        expectFilter(
            #Predicate<DescriptionDTO> { $0.name == "Moved to Q2" },
            docJSON: #"{"property":"Name","title":{"equals":"Moved to Q2"}}"#
        )
        expectFilter(
            #Predicate<DescriptionDTO> { $0.name != "Moved to Q2" },
            docJSON: #"{"property":"Name","title":{"does_not_equal":"Moved to Q2"}}"#
        )
        expectFilter(
            #Predicate<DescriptionDTO> { $0.name.contains("Moved to Q2") },
            docJSON: #"{"property":"Name","title":{"contains":"Moved to Q2"}}"#
        )
        expectFilter(
            #Predicate<DescriptionDTO> { $0.name.starts(with: "Moved") },
            docJSON: #"{"property":"Name","title":{"starts_with":"Moved"}}"#
        )
    }

    // MARK: Rejections

    @Test
    @available(macOS 14.0, *)
    func negatedStartsWithIsRejected() {
        // The page lists `starts_with` but no "does not start with" condition.
        expectConversionError(
            #Predicate<DescriptionDTO> { !$0.description.starts(with: "Moved") },
            "negated starts-with is not expressible",
            matches: isUnsupportedRoot
        )
    }

    @Test
    @available(macOS 14.0, *)
    func fileURLEqualityIsRejected() {
        // The page offers only `is_empty`/`is_not_empty` for files.
        let blueprintURL = URL(string: "https://example.com/blueprint.pdf")!
        expectConversionError(
            #Predicate<BlueprintDTO> { $0.blueprint == blueprintURL },
            "file URL equality is not expressible",
            matches: isUnsupportedRoot
        )
    }

    @Test
    @available(macOS 14.0, *)
    func compoundPredicateIsRejected() {
        // `and`/`or` exist as NotionFilter cases (see FilterDocsParityTests),
        // but predicate conjunctions do not convert.
        expectConversionError(
            #Predicate<TaskDTO> { $0.completed && $0.done },
            "compound predicates are not expressible",
            matches: isUnsupportedRoot
        )
    }

    @Test
    @available(macOS 14.0, *)
    func unregisteredKeyPathIsRejected() {
        // A bare Bool key path is only convertible when it is a direct key path
        // to a checkbox property; `String.isEmpty` hangs off a text field, so
        // neither the checkbox nor the files `isEmpty` conformance applies.
        expectConversionError(
            #Predicate<DescriptionDTO> { $0.description.isEmpty },
            "a non-checkbox Bool key path is not expressible",
            matches: isUnsupportedRoot
        )
        // A Bool property with no Notion annotation is a checkbox-shaped key
        // path that resolves to no field.
        expectConversionError(
            #Predicate<UnregisteredBoolDTO> { $0.flag },
            "a Bool key path with no registered Notion field is not expressible",
            matches: isUnsupportedField
        )
    }
}
