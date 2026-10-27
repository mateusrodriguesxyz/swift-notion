//
//  FilterDocsParityTests.swift
//  NotionMacrosTests
//
//  Expected JSON bodies are copied from
//  https://developers.notion.com/reference/filter-data-source-entries.

import Foundation
import SwiftNotion
import Testing

@Suite
struct FilterDocsParityTests {
    // MARK: Checkbox

    @Test
    func checkboxDocExamplesEncode() {
        // "Example checkbox filter object" and the intro cURL body.
        expectEncodes(
            .checkbox("Task completed", equals: true),
            docJSON: """
            {
              "property": "Task completed",
              "checkbox": { "equals": true }
            }
            """
        )
        expectEncodesQueryBody(
            .checkbox("Task completed", equals: true),
            docJSON: """
            {
              "filter": {
                "property": "Task completed",
                "checkbox": { "equals": true }
              }
            }
            """
        )
        // Checkbox table example value for `equals`.
        expectEncodes(
            .checkbox("Task completed", equals: false),
            docJSON: #"{"property":"Task completed","checkbox":{"equals":false}}"#
        )
        // The docs also accept `checkbox.does_not_equal`; NotionFilter has no
        // such case. The predicate path expresses inequality as the opposite
        // `equals` value (see PredicateFilterTests), which matches the docs'
        // description of `does_not_equal`.
    }

    // MARK: Date

    @Test
    func dateDocExamplesEncode() {
        // "Example date filter condition".
        expectEncodes(
            .date("Due date", .onOrAfter(utcDate(2023, 2, 8))),
            docJSON: """
            {
              "property": "Due date",
              "date": { "on_or_after": "2023-02-08" }
            }
            """
        )
        // The docs' relative date form (`"on_or_after": "today"`) is not
        // expressible: DateCondition takes a Date and writes `yyyy-MM-dd`.
        let tableDate = utcDate(2021, 5, 10)
        expectEncodes(
            .date("Due date", .equals(tableDate)),
            docJSON: #"{"property":"Due date","date":{"equals":"2021-05-10"}}"#
        )
        expectEncodes(
            .date("Due date", .before(tableDate)),
            docJSON: #"{"property":"Due date","date":{"before":"2021-05-10"}}"#
        )
        expectEncodes(
            .date("Due date", .after(tableDate)),
            docJSON: #"{"property":"Due date","date":{"after":"2021-05-10"}}"#
        )
        expectEncodes(
            .date("Due date", .onOrBefore(tableDate)),
            docJSON: #"{"property":"Due date","date":{"on_or_before":"2021-05-10"}}"#
        )
        expectEncodes(
            .date("Due date", .isEmpty),
            docJSON: #"{"property":"Due date","date":{"is_empty":true}}"#
        )
        expectEncodes(
            .date("Due date", .isNotEmpty),
            docJSON: #"{"property":"Due date","date":{"is_not_empty":true}}"#
        )
    }

    // MARK: Files

    @Test
    func filesDocExamplesEncode() {
        // "Example files filter condition".
        expectEncodes(
            .files("Blueprint", .isNotEmpty),
            docJSON: """
            {
              "property": "Blueprint",
              "files": { "is_not_empty": true }
            }
            """
        )
        expectEncodes(
            .files("Blueprint", .isEmpty),
            docJSON: #"{"property":"Blueprint","files":{"is_empty":true}}"#
        )
    }

    // MARK: Multi-select

    @Test
    func multiSelectDocExamplesEncode() {
        // "Example multi-select filter condition".
        expectEncodes(
            .multiSelect("Programming language", contains: "TypeScript"),
            docJSON: """
            {
              "property": "Programming language",
              "multi_select": { "contains": "TypeScript" }
            }
            """
        )
        // Not modelled: `does_not_contain`, `is_empty`, `is_not_empty`, and the
        // string-array operand form.
    }

    // MARK: Number

    @Test
    func numberDocExamplesEncode() {
        // "Example number filter condition".
        expectEncodes(
            .number("Estimated working days", .lessThanOrEqualTo(5)),
            docJSON: """
            {
              "property": "Estimated working days",
              "number": { "less_than_or_equal_to": 5 }
            }
            """
        )
        // Number table, example value 42.
        expectEncodes(
            .number("Estimated working days", .equals(42)),
            docJSON: #"{"property":"Estimated working days","number":{"equals":42}}"#
        )
        expectEncodes(
            .number("Estimated working days", .doesNotEqual(42)),
            docJSON: #"{"property":"Estimated working days","number":{"does_not_equal":42}}"#
        )
        expectEncodes(
            .number("Estimated working days", .greaterThan(42)),
            docJSON: #"{"property":"Estimated working days","number":{"greater_than":42}}"#
        )
        expectEncodes(
            .number("Estimated working days", .lessThan(42)),
            docJSON: #"{"property":"Estimated working days","number":{"less_than":42}}"#
        )
        expectEncodes(
            .number("Estimated working days", .greaterThanOrEqualTo(42)),
            docJSON: #"{"property":"Estimated working days","number":{"greater_than_or_equal_to":42}}"#
        )
        expectEncodes(
            .number("Estimated working days", .lessThanOrEqualTo(42)),
            docJSON: #"{"property":"Estimated working days","number":{"less_than_or_equal_to":42}}"#
        )
        expectEncodes(
            .number("Estimated working days", .isEmpty),
            docJSON: #"{"property":"Estimated working days","number":{"is_empty":true}}"#
        )
        expectEncodes(
            .number("Estimated working days", .isNotEmpty),
            docJSON: #"{"property":"Estimated working days","number":{"is_not_empty":true}}"#
        )
    }

    // MARK: Relation

    @Test
    func relationDocExamplesEncode() {
        // "Example relation filter condition". The docs write the UUID undashed
        // ("0c1f7cb280904f18924ed92965055e32"); the encoder emits the dashed,
        // lowercased form of the same UUIDv4.
        let taskListID = UUID(uuidString: "0c1f7cb2-8090-4f18-924e-d92965055e32")!
        expectEncodes(
            .relation("✔️ Task List", .contains(taskListID)),
            docJSON: """
            {
              "property": "✔️ Task List",
              "relation": { "contains": "0c1f7cb2-8090-4f18-924e-d92965055e32" }
            }
            """
        )
        expectEncodes(
            .relation("✔️ Task List", .doesNotContain(taskListID)),
            docJSON: #"{"property":"✔️ Task List","relation":{"does_not_contain":"0c1f7cb2-8090-4f18-924e-d92965055e32"}}"#
        )
        // Not modelled: relation `is_empty`/`is_not_empty`.
    }

    // MARK: Rich text

    @Test
    func richTextDocExamplesEncode() {
        // "Example rich text filter condition".
        expectEncodes(
            .richText("Description", .contains("cross-team")),
            docJSON: """
            {
              "property": "Description",
              "rich_text": { "contains": "cross-team" }
            }
            """
        )
        // Rich text table examples. `ends_with` has no predicate route
        // (`String.hasSuffix` does not produce a convertible node).
        let conditions: [(TextCondition, String)] = [
            (.equals("Moved to Q2"), #"{"property":"Description","rich_text":{"equals":"Moved to Q2"}}"#),
            (.doesNotEqual("Moved to Q2"), #"{"property":"Description","rich_text":{"does_not_equal":"Moved to Q2"}}"#),
            (.contains("Moved to Q2"), #"{"property":"Description","rich_text":{"contains":"Moved to Q2"}}"#),
            (.doesNotContain("Moved to Q2"), #"{"property":"Description","rich_text":{"does_not_contain":"Moved to Q2"}}"#),
            (.startsWith("Moved"), #"{"property":"Description","rich_text":{"starts_with":"Moved"}}"#),
            (.endsWith("Q2"), #"{"property":"Description","rich_text":{"ends_with":"Q2"}}"#),
            (.isEmpty, #"{"property":"Description","rich_text":{"is_empty":true}}"#),
            (.isNotEmpty, #"{"property":"Description","rich_text":{"is_not_empty":true}}"#),
        ]
        for (condition, json) in conditions {
            expectEncodes(.richText("Description", condition), docJSON: json)
        }
    }

    // MARK: Select

    @Test
    func selectDocExamplesEncode() {
        // "Example select filter condition".
        expectEncodes(
            .select("Frontend framework", equals: "React"),
            docJSON: """
            {
              "property": "Frontend framework",
              "select": { "equals": "React" }
            }
            """
        )
        // Not modelled: `does_not_equal`, `is_empty`, `is_not_empty`, and the
        // string-array operand form (`"does_not_equal": ["Done", "Archive"]`).
    }

    // MARK: Compound

    @Test
    func compoundDocExamplesEncode() {
        // "Example compound filter condition for a checkbox and number property".
        expectEncodesQueryBody(
            .and([
                .checkbox("Complete", equals: true),
                .number("Working days", .greaterThan(10)),
            ]),
            docJSON: """
            {
              "filter": {
                "and": [
                  {
                    "property": "Complete",
                    "checkbox": { "equals": true }
                  },
                  {
                    "property": "Working days",
                    "number": { "greater_than": 10 }
                  }
                ]
              }
            }
            """
        )

        // "Example nested filter condition".
        expectEncodesQueryBody(
            .or([
                .richText("Description", .contains("2023")),
                .and([
                    .select("Department", equals: "Engineering"),
                    .checkbox("Priority goal", equals: true),
                ]),
            ]),
            docJSON: """
            {
              "filter": {
                "or": [
                  {
                    "property": "Description",
                    "rich_text": { "contains": "2023" }
                  },
                  {
                    "and": [
                      {
                        "property": "Department",
                        "select": { "equals": "Engineering" }
                      },
                      {
                        "property": "Priority goal",
                        "checkbox": { "equals": true }
                      }
                    ]
                  }
                ]
              }
            }
            """
        )

        // The docs' introductory and/or example. It is abbreviated: its "Tags"
        // leaves ("property": "Tags", "contains": "A") omit the property-type
        // key, so the encoded form wraps them in `rich_text`.
        expectEncodes(
            .and([
                .checkbox("Done", equals: true),
                .or([
                    .richText("Tags", .contains("A")),
                    .richText("Tags", .contains("B")),
                ]),
            ]),
            docJSON: """
            {
              "and": [
                {
                  "property": "Done",
                  "checkbox": { "equals": true }
                },
                {
                  "or": [
                    {
                      "property": "Tags",
                      "rich_text": { "contains": "A" }
                    },
                    {
                      "property": "Tags",
                      "rich_text": { "contains": "B" }
                    }
                  ]
                }
              ]
            }
            """
        )
    }

    // MARK: Unmodelled conditions
    //
    // The page also documents filter kinds that NotionFilter has no case for,
    // so no encoding assertion is possible:
    //
    // - `formula` ("One month deadline"), including the nested date condition
    // - `rollup` ("Related tasks", "Parent project due date", "Total estimated
    //   working days") with `any`/`every`/`none`
    // - `people` ("Last edited by", "Assignee"), including the "me" operand
    // - `status` ("Project status"), including `group_equals` and the
    //   status-group-filters beta
    // - `timestamp` (`created_time`/`last_edited_time`), which must not carry a
    //   property name
    // - `verification` ("verification")
    // - `unique_id` ("ID")
    // - relative date operands ("today", "tomorrow", "yesterday", …)
    // - select/multi-select string-array operands
}
