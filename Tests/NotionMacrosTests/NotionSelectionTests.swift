import Foundation
import Notion
import Testing

enum WorkflowStatus: String {
    case open = "Open"
    case closed = "Closed"
}

enum TaskTag: String {
    case urgent = "Urgent"
    case blocked = "Blocked"
}

@NotionPage
struct SelectionMappingPage {
    @NotionProperty("Status") var status: WorkflowStatus?
    @NotionProperty("Tags") var tags: [TaskTag]
    @NotionSelect("Explicit Status") var explicitStatus: WorkflowStatus?
    @NotionMultiSelect("Explicit Tags") var explicitTags: [TaskTag]
}

@Suite
struct NotionSelectionTests {
    private func pageData(
        status: String? = "Open",
        tags: [String] = ["Urgent", "Blocked"],
        explicitStatus: String? = "Closed",
        explicitTags: [String] = ["Blocked"]
    ) throws -> Data {
        func selectValue(_ name: String?) -> Any {
            guard let name else { return NSNull() }
            return ["name": name]
        }

        return try JSONSerialization.data(withJSONObject: [
            "id": "0c1f7cb2-8090-4f18-924e-d92965055e32",
            "properties": [
                "Status": ["type": "select", "select": selectValue(status)],
                "Tags": ["type": "multi_select", "multi_select": tags.map { ["name": $0] }],
                "Explicit Status": ["type": "select", "select": selectValue(explicitStatus)],
                "Explicit Tags": ["type": "multi_select", "multi_select": explicitTags.map { ["name": $0] }]
            ] as [String: Any]
        ])
    }

    @Test
    func decodesInferredAndExplicitEnumProperties() throws {
        let page = try JSONDecoder().decode(SelectionMappingPage.self, from: pageData())

        #expect(page.status == .open)
        #expect(page.tags == [.urgent, .blocked])
        #expect(page.explicitStatus == .closed)
        #expect(page.explicitTags == [.blocked])
    }

    @Test
    func decodesNullSelectAsNil() throws {
        let page = try JSONDecoder().decode(
            SelectionMappingPage.self,
            from: pageData(status: nil, explicitStatus: nil)
        )

        #expect(page.status == nil)
        #expect(page.explicitStatus == nil)
    }

    @Test
    func throwsForUnknownSelectOption() throws {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                SelectionMappingPage.self,
                from: pageData(status: "In progress")
            )
        }
    }

    @Test
    func throwsForUnknownMultiSelectOption() throws {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                SelectionMappingPage.self,
                from: pageData(tags: ["Urgent", "Unrecognized"])
            )
        }
    }

    @Test
    func reportsMissingSelectionProperty() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "id": "0c1f7cb2-8090-4f18-924e-d92965055e32",
            "properties": [:] as [String: String]
        ])

        #expect(throws: NotionError.self) {
            try JSONDecoder().decode(SelectionMappingPage.self, from: data)
        }
    }

    @Test
    func encodesEnumValuesAsNotionOptionNames() throws {
        let page = try JSONDecoder().decode(SelectionMappingPage.self, from: pageData())
        let encoded = try JSONEncoder().encode(page)
        let json = String(decoding: encoded, as: UTF8.self)

        #expect(normalizedJSON(json) == normalizedJSON("""
        {
          "properties": {
            "Status": { "select": { "name": "Open" } },
            "Tags": { "multi_select": [{ "name": "Urgent" }, { "name": "Blocked" }] },
            "Explicit Status": { "select": { "name": "Closed" } },
            "Explicit Tags": { "multi_select": [{ "name": "Blocked" }] }
          }
        }
        """))
    }

    @Test
    func registersSelectionKindsInPropertyMetadata() {
        #expect(SelectionMappingPage.notionProperty(for: \.status)?.kind == .select)
        #expect(SelectionMappingPage.notionProperty(for: \.tags)?.kind == .multiSelect)
        #expect(SelectionMappingPage.notionProperty(for: \.explicitStatus)?.kind == .select)
        #expect(SelectionMappingPage.notionProperty(for: \.explicitTags)?.kind == .multiSelect)
    }
}
