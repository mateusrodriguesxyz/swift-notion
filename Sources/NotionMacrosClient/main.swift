import NotionMacros
import Foundation

@NotionPage
struct ArtistDTO: Decodable {
    @NotionTitle("Nome") var name: String
    @NotionProperty("Bio") var bio: String
    @NotionProperty("Foto") var photoURL: URL?
}

@NotionPage
struct ArtDTO: Decodable {
    @NotionTitle("Nome") var name: String
    @NotionProperty("Foto Principal") var mainPhotoURL: URL?
    @NotionProperty("Fotos Extras") var extraPhotoURLs: [URL]
    @NotionProperty("Descrição") var description: String
    @NotionProperty("Evento") var event: String
    @NotionProperty("Endereço") var address: String
    @NotionProperty("Coordenadas") var coordinates: String
    @NotionProperty("Data") var date: Date?
    @NotionRelationIDs("Artistas") var artistIDs: [UUID]
}

@NotionPage
struct EventDTO: Decodable {
    @NotionTitle("Nome") var name: String
    @NotionDateRange("Data") var period: Range<Date>?
    @NotionDateStart("Início") var start: Date?
    @NotionRelationIDs("Convidados") var guestIDs: [UUID]
}

/// A `@NotionPage` type used to prove a captured DTO id key path resolves in a
/// `#Predicate` (`Value<Output>` is a `StandardPredicateExpression` only when
/// `Output` is `Codable`; `@NotionPage` synthesizes `Encodable`).
@NotionPage
struct CapturedArtistDTO: Decodable {
    @NotionTitle("Nome") var name: String
}

@NotionPage
struct FeedbackDTO: Decodable {
    @NotionTitle("Nome") var name: String
    @NotionCheckbox("Publicado") var published: Bool
    @NotionNumber("Nota") var score: Double?
    @NotionProperty("Peso") var weight: Double?
    @NotionProperty("Ativo") var active: Bool
}

/// Used to prove an empty string encodes as an empty array (Notion's clear).
@NotionPage
struct BlankDTO: Decodable {
    @NotionTitle("Nome") var name: String
    @NotionRichText("Bio") var bio: String
}

struct ListResponse<T: Decodable>: Decodable {
    let results: [T]
}

let artistsJSON = """
{
  "object": "list",
  "results": [
    {
      "object": "page",
      "id": "11111111-1111-1111-1111-111111111111",
      "properties": {
        "Nome": { "type": "title", "title": [ { "plain_text": "Artista Teste" } ] },
        "Bio": { "type": "rich_text", "rich_text": [ { "plain_text": "Bio teste" } ] },
        "Foto": { "type": "files", "files": [ { "name": "foto", "file": { "url": "https://example.com/artista.jpg" } } ] }
      }
    }
  ]
}
""".data(using: .utf8)!

let artsJSON = """
{
  "object": "list",
  "results": [
    {
      "object": "page",
      "id": "22222222-2222-2222-2222-222222222222",
      "properties": {
        "Nome": { "type": "title", "title": [ { "plain_text": "Obra Teste" } ] },
        "Foto Principal": { "type": "files", "files": [ { "file": { "url": "https://example.com/main.jpg" } } ] },
        "Fotos Extras": { "type": "files", "files": [ { "file": { "url": "https://example.com/extra1.jpg" } }, { "file": { "url": "https://example.com/extra2.jpg" } } ] },
        "Descrição": { "type": "rich_text", "rich_text": [ { "plain_text": "Descrição teste" } ] },
        "Evento": { "type": "rich_text", "rich_text": [ { "plain_text": "Evento teste" } ] },
        "Endereço": { "type": "rich_text", "rich_text": [ { "plain_text": "Endereço teste" } ] },
        "Coordenadas": { "type": "rich_text", "rich_text": [ { "plain_text": "-3.73, -38.49" } ] },
        "Data": { "type": "date", "date": { "start": "2026-09-07" } },
        "Artistas": { "type": "relation", "relation": [ { "id": "4d195b29-4b07-41de-8029-6c0d9e607e4b" } ] }
      }
    }
  ]
}
""".data(using: .utf8)!

let artsWithTimeJSON = """
{
  "object": "list",
  "results": [
    {
      "object": "page",
      "id": "33333333-3333-3333-3333-333333333333",
      "properties": {
        "Nome": { "type": "title", "title": [ { "plain_text": "Obra com horário" } ] },
        "Data": { "type": "date", "date": { "start": "2026-09-07T12:00:00.000-03:00" } }
      }
    }
  ]
}
""".data(using: .utf8)!

let eventRangeJSON = """
{
  "id": "44444444-4444-4444-4444-444444444444",
  "properties": {
    "Nome": { "type": "title", "title": [ { "plain_text": "Evento" } ] },
    "Data": { "type": "date", "date": { "start": "2026-09-07", "end": "2026-09-10" } },
    "Início": { "type": "date", "date": { "start": "2026-09-01" } },
    "Convidados": { "type": "relation", "relation": [ { "id": "77777777-7777-7777-7777-777777777777" }, { "id": "not-a-uuid" } ] }
  }
}
""".data(using: .utf8)!

let eventSingleJSON = """
{
  "id": "55555555-5555-5555-5555-555555555555",
  "properties": {
    "Nome": { "type": "title", "title": [ { "plain_text": "Evento único" } ] },
    "Data": { "type": "date", "date": { "start": "2026-09-07" } }
  }
}
""".data(using: .utf8)!

let eventReversedJSON = """
{
  "id": "66666666-6666-6666-6666-666666666666",
  "properties": {
    "Nome": { "type": "title", "title": [ { "plain_text": "Evento invertido" } ] },
    "Data": { "type": "date", "date": { "start": "2026-09-10", "end": "2026-09-07" } }
  }
}
""".data(using: .utf8)!

let capturedArtistJSON = """
{
  "id": "88888888-8888-8888-8888-888888888888",
  "properties": {
    "Nome": { "type": "title", "title": [ { "plain_text": "Artista capturado" } ] }
  }
}
""".data(using: .utf8)!

let feedbackJSON = """
{
  "id": "99999999-9999-9999-9999-999999999999",
  "properties": {
    "Nome": { "type": "title", "title": [ { "plain_text": "Feedback" } ] },
    "Publicado": { "type": "checkbox", "checkbox": true },
    "Nota": { "type": "number", "number": 8 },
    "Peso": { "type": "number", "number": 1.5 },
    "Ativo": { "type": "checkbox", "checkbox": true }
  }
}
""".data(using: .utf8)!

let feedbackEmptyNumberJSON = """
{
  "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
  "properties": {
    "Nome": { "type": "title", "title": [ { "plain_text": "Feedback vazio" } ] },
    "Nota": { "type": "number", "number": null },
    "Ativo": { "type": "checkbox", "checkbox": false }
  }
}
""".data(using: .utf8)!

func check(_ condition: Bool, _ message: String) {
    if condition {
        print("PASS: \(message)")
    } else {
        print("FAIL: \(message)")
        exit(1)
    }
}

func utcDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar.date(from: components)!
}

/// Serializes JSON with sorted keys so equality does not depend on key order.
func normalizedJSON(_ value: Any) -> String {
    let data = try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    return String(data: data, encoding: .utf8)!
}

func encodedFilter(_ filter: NotionFilter) -> String {
    normalizedJSON(try! JSONSerialization.jsonObject(with: JSONEncoder().encode(filter)))
}

do {
    let artist = try JSONDecoder().decode(ListResponse<ArtistDTO>.self, from: artistsJSON).results[0]
    check(artist.id == UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, "artist id decoded as UUID")
    check(artist.name == "Artista Teste", "artist title decoded")
    check(artist.bio == "Bio teste", "artist rich text decoded")
    check(artist.photoURL == URL(string: "https://example.com/artista.jpg"), "artist file URL decoded")

    let art = try JSONDecoder().decode(ListResponse<ArtDTO>.self, from: artsJSON).results[0]
    check(art.id == UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, "art id decoded as UUID")
    check(art.name == "Obra Teste", "art title decoded")
    check(art.mainPhotoURL == URL(string: "https://example.com/main.jpg"), "art main photo decoded")
    check(art.extraPhotoURLs == [URL(string: "https://example.com/extra1.jpg")!, URL(string: "https://example.com/extra2.jpg")!], "art extra photos decoded")
    check(art.description == "Descrição teste", "art description decoded")
    check(art.event == "Evento teste", "art event decoded")
    check(art.address == "Endereço teste", "art address decoded")
    check(art.coordinates == "-3.73, -38.49", "art coordinates decoded")
    check(art.date == utcDate(2026, 9, 7), "art date-only decoded")
    check(art.artistIDs == [UUID(uuidString: "4d195b29-4b07-41de-8029-6c0d9e607e4b")!], "art relations decoded as UUID")

    let timedArt = try JSONDecoder().decode(ListResponse<ArtDTO>.self, from: artsWithTimeJSON).results[0]
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    check(timedArt.date == iso.date(from: "2026-09-07T12:00:00.000-03:00"), "art datetime decoded")
    check(NotionDecoding.date(from: "") == nil, "empty date decodes to nil")

    let event = try JSONDecoder().decode(EventDTO.self, from: eventRangeJSON)
    check(event.period == (utcDate(2026, 9, 7) ..< utcDate(2026, 9, 10)), "date range decoded")
    check(event.start == utcDate(2026, 9, 1), "explicit NotionDateStart still decodes")
    check(event.guestIDs == [UUID(uuidString: "77777777-7777-7777-7777-777777777777")!], "relation ids decode as UUID and malformed ids are dropped")

    let singleEvent = try JSONDecoder().decode(EventDTO.self, from: eventSingleJSON)
    check(singleEvent.period == nil, "single date yields no range")

    let reversedEvent = try JSONDecoder().decode(EventDTO.self, from: eventReversedJSON)
    check(reversedEvent.period == nil, "end before start yields no range")

    let missingID = try JSONDecoder().decode(EventDTO.self, from: Data("{\"properties\":{}}".utf8))
    check(missingID.id == UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)), "missing id falls back to zero UUID")

    check(ArtistDTO.notionProperties[\.name] == NotionField(name: "Nome", kind: .title), "artist title keypath maps to field")
    check(ArtistDTO.notionProperties[\.bio] == NotionField(name: "Bio", kind: .richText), "artist rich text keypath maps to field")
    check(ArtistDTO.notionProperties[\.photoURL] == NotionField(name: "Foto", kind: .file), "artist file keypath maps to field")
    check(ArtistDTO.notionProperties.count == 3, "artist map has exactly the annotated properties")
    check(ArtDTO.notionProperties[\.name] == NotionField(name: "Nome", kind: .title), "art title keypath maps to field")
    check(ArtDTO.notionProperties[\.mainPhotoURL] == NotionField(name: "Foto Principal", kind: .file), "art file keypath maps to field")
    check(ArtDTO.notionProperties[\.extraPhotoURLs] == NotionField(name: "Fotos Extras", kind: .files), "art files keypath maps to field")
    check(ArtDTO.notionProperties[\.date] == NotionField(name: "Data", kind: .date), "art date keypath maps to field")
    check(ArtDTO.notionProperties[\.artistIDs] == NotionField(name: "Artistas", kind: .relation), "art relation keypath maps to field")
    check(ArtDTO.notionProperties.count == 9, "art map has exactly the annotated properties")
    check(EventDTO.notionProperties[\.period] == NotionField(name: "Data", kind: .dateRange), "date range keypath maps to field")
    check(EventDTO.notionProperties[\.guestIDs] == NotionField(name: "Convidados", kind: .relation), "event relation keypath maps to field")
    check(ArtistDTO.notionField(for: \.name) == "Nome", "notionField resolves a registered keypath")
    check(ArtistDTO.notionProperty(for: \.name)?.kind == .title, "notionProperty resolves kind")
    check(ArtDTO.notionProperty(for: \.description)?.kind == .richText, "@NotionProperty String resolves to richText")
    check(ArtistDTO.notionField(for: \.id) == nil, "generated id keypath is not in the map")

    let encodedArtist = normalizedJSON(try JSONSerialization.jsonObject(with: JSONEncoder().encode(artist)))
    check(
        encodedArtist == normalizedJSON([
            "properties": [
                "Nome": ["title": [["type": "text", "text": ["content": "Artista Teste"]]]],
                "Bio": ["rich_text": [["type": "text", "text": ["content": "Bio teste"]]]],
                "Foto": ["files": [["name": "artista.jpg", "type": "external", "external": ["url": "https://example.com/artista.jpg"]]]],
            ] as [String: Any],
        ]),
        "artist encodes Notion-shaped values without id"
    )

    let encodedArt = try JSONSerialization.jsonObject(with: JSONEncoder().encode(art)) as! [String: Any]
    check(encodedArt["id"] == nil, "art output has no top-level id")
    check(
        normalizedJSON(encodedArt["properties"] as! [String: Any]) ==
        normalizedJSON([
            "Nome": ["title": [["type": "text", "text": ["content": "Obra Teste"]]]],
            "Foto Principal": ["files": [["name": "main.jpg", "type": "external", "external": ["url": "https://example.com/main.jpg"]]]],
            "Fotos Extras": ["files": [
                ["name": "extra1.jpg", "type": "external", "external": ["url": "https://example.com/extra1.jpg"]],
                ["name": "extra2.jpg", "type": "external", "external": ["url": "https://example.com/extra2.jpg"]],
            ]],
            "Descrição": ["rich_text": [["type": "text", "text": ["content": "Descrição teste"]]]],
            "Evento": ["rich_text": [["type": "text", "text": ["content": "Evento teste"]]]],
            "Endereço": ["rich_text": [["type": "text", "text": ["content": "Endereço teste"]]]],
            "Coordenadas": ["rich_text": [["type": "text", "text": ["content": "-3.73, -38.49"]]]],
            "Data": ["date": ["start": "2026-09-07"]],
            "Artistas": ["relation": [["id": "4D195B29-4B07-41DE-8029-6C0D9E607E4B"]]],
        ] as [String: Any]),
        "art encodes Notion-shaped title, files, rich text, date and relation"
    )

    let timedArtProperties = (try JSONSerialization.jsonObject(with: JSONEncoder().encode(timedArt)) as! [String: Any])["properties"] as! [String: Any]
    let timedDateStart = (timedArtProperties["Data"] as? [String: Any])?["date"].flatMap { ($0 as? [String: Any])?["start"] } as? String
    check(timedDateStart == "2026-09-07T15:00:00Z", "a timed date encodes as ISO-8601, not date-only")

    let encodedEvent = try JSONSerialization.jsonObject(with: JSONEncoder().encode(event)) as! [String: Any]
    check(
        normalizedJSON(encodedEvent["properties"] as! [String: Any]) ==
        normalizedJSON([
            "Nome": ["title": [["type": "text", "text": ["content": "Evento"]]]],
            "Data": ["date": ["start": "2026-09-07", "end": "2026-09-10"]],
            "Início": ["date": ["start": "2026-09-01"]],
            "Convidados": ["relation": [["id": "77777777-7777-7777-7777-777777777777"]]],
        ] as [String: Any]),
        "event encodes a Notion date range and relation"
    )

    let blank = try JSONDecoder().decode(BlankDTO.self, from: Data("{\"properties\":{}}".utf8))
    check(
        normalizedJSON(try JSONSerialization.jsonObject(with: JSONEncoder().encode(blank))) ==
        normalizedJSON([
            "properties": [
                "Nome": ["title": [] as [[String: Any]]],
                "Bio": ["rich_text": [] as [[String: Any]]],
            ] as [String: Any],
        ]),
        "an empty string encodes as an empty array (Notion clear)"
    )

    check(
        encodedFilter(.relation("Artistas", .contains(UUID(uuidString: "4d195b29-4b07-41de-8029-6c0d9e607e4b")!))) ==
        normalizedJSON(["property": "Artistas", "relation": ["contains": "4d195b29-4b07-41de-8029-6c0d9e607e4b"]]),
        "relation filter encodes to Notion shape"
    )
    check(
        encodedFilter(.and([.title("Nome", .equals("X")), .richText("Bio", .contains("Y"))])) ==
        normalizedJSON(["and": [
            ["property": "Nome", "title": ["equals": "X"]],
            ["property": "Bio", "rich_text": ["contains": "Y"]]
        ]]),
        "compound filter encodes to Notion shape"
    )
    check(
        encodedFilter(.date("Data", .isNotEmpty)) ==
        normalizedJSON(["property": "Data", "date": ["is_not_empty": true]]),
        "empty date condition encodes"
    )
    check(
        encodedFilter(.files("Blueprint", .isNotEmpty)) ==
        normalizedJSON(["property": "Blueprint", "files": ["is_not_empty": true]]),
        "files condition encodes"
    )
    check(
        encodedFilter(.files("Blueprint", .isEmpty)) ==
        normalizedJSON(["property": "Blueprint", "files": ["is_empty": true]]),
        "empty files condition encodes"
    )

    if #available(macOS 14.0, *) {
        let titlePredicate = #Predicate<ArtDTO> { $0.name == "Obra Teste" }
        let titleFilter = try notionFilter(titlePredicate)
        check(titleFilter == .title("Nome", .equals("Obra Teste")), "predicate title equality converts")
        check(
            encodedFilter(titleFilter) == normalizedJSON(["property": "Nome", "title": ["equals": "Obra Teste"]]),
            "predicate-derived filter encodes to Notion shape"
        )

        let artistID = UUID(uuidString: "4d195b29-4b07-41de-8029-6c0d9e607e4b")!
        let relationPredicate = #Predicate<ArtDTO> { $0.artistIDs.contains(artistID) }
        let relationFilter = try notionFilter(relationPredicate)
        check(relationFilter == .relation("Artistas", .contains(artistID)), "predicate relation contains converts")
        check(
            encodedFilter(relationFilter) == normalizedJSON(["property": "Artistas", "relation": ["contains": "4d195b29-4b07-41de-8029-6c0d9e607e4b"]]),
            "predicate-derived relation filter encodes to Notion shape"
        )

        let capturedArtist = try JSONDecoder().decode(CapturedArtistDTO.self, from: capturedArtistJSON)
        let capturedPredicate = #Predicate<ArtDTO> { $0.artistIDs.contains(capturedArtist.id) }
        let capturedFilter = try notionFilter(capturedPredicate)
        check(
            capturedFilter == .relation("Artistas", .contains(capturedArtist.id)),
            "predicate resolves a captured DTO id key path to a literal"
        )
        check(
            encodedFilter(capturedFilter) == normalizedJSON(["property": "Artistas", "relation": ["contains": "88888888-8888-8888-8888-888888888888"]]),
            "captured-id predicate encodes to Notion shape"
        )

        let negatedRelationPredicate = #Predicate<ArtDTO> { !$0.artistIDs.contains(artistID) }
        let negatedRelationFilter = try notionFilter(negatedRelationPredicate)
        check(
            negatedRelationFilter == .relation("Artistas", .doesNotContain(artistID)),
            "negated relation contains converts to does_not_contain"
        )
        check(
            encodedFilter(negatedRelationFilter) == normalizedJSON(["property": "Artistas", "relation": ["does_not_contain": "4d195b29-4b07-41de-8029-6c0d9e607e4b"]]),
            "negated relation filter encodes to Notion shape"
        )

        let negatedTitlePredicate = #Predicate<ArtDTO> { !($0.name == "Obra Teste") }
        let negatedTitleFilter = try notionFilter(negatedTitlePredicate)
        check(
            negatedTitleFilter == .title("Nome", .doesNotEqual("Obra Teste")),
            "negated title equality converts to does_not_equal"
        )
        check(
            encodedFilter(negatedTitleFilter) == normalizedJSON(["property": "Nome", "title": ["does_not_equal": "Obra Teste"]]),
            "negated title filter encodes to Notion shape"
        )

        let negatedCapturedPredicate = #Predicate<ArtDTO> { !$0.artistIDs.contains(capturedArtist.id) }
        check(
            try notionFilter(negatedCapturedPredicate) == .relation("Artistas", .doesNotContain(capturedArtist.id)),
            "negated predicate resolves a captured DTO id key path to a literal"
        )

        let factoryTitleFilter: NotionFilter = try .predicate(titlePredicate)
        check(
            factoryTitleFilter == titleFilter,
            "NotionFilter.predicate factory agrees with notionFilter for title equality"
        )
        check(
            encodedFilter(factoryTitleFilter) ==
            normalizedJSON(["property": "Nome", "title": ["equals": "Obra Teste"]]),
            "factory-derived title filter encodes to Notion shape"
        )
        let factoryRelationFilter: NotionFilter = try .predicate(relationPredicate)
        check(
            factoryRelationFilter == relationFilter,
            "NotionFilter.predicate factory agrees with notionFilter for relation contains"
        )
        let factoryCapturedFilter: NotionFilter = try .predicate(capturedPredicate)
        check(
            encodedFilter(factoryCapturedFilter) ==
            normalizedJSON(["property": "Artistas", "relation": ["contains": "88888888-8888-8888-8888-888888888888"]]),
            "factory-derived captured-id filter encodes to Notion shape"
        )

        let richTextPredicate = #Predicate<ArtDTO> { $0.description == "Descrição teste" }
        let richTextFilter = try notionFilter(richTextPredicate)
        check(
            richTextFilter == .richText("Descrição", .equals("Descrição teste")),
            "predicate rich text equality converts"
        )
        check(
            encodedFilter(richTextFilter) == normalizedJSON(["property": "Descrição", "rich_text": ["equals": "Descrição teste"]]),
            "predicate-derived rich text filter encodes to Notion shape"
        )

        let negatedRichTextPredicate = #Predicate<ArtDTO> { !($0.description == "Descrição teste") }
        let negatedRichTextFilter = try notionFilter(negatedRichTextPredicate)
        check(
            negatedRichTextFilter == .richText("Descrição", .doesNotEqual("Descrição teste")),
            "negated rich text equality converts to does_not_equal"
        )
        check(
            encodedFilter(negatedRichTextFilter) == normalizedJSON(["property": "Descrição", "rich_text": ["does_not_equal": "Descrição teste"]]),
            "negated rich text filter encodes to Notion shape"
        )

        let bioContainsPredicate = #Predicate<ArtistDTO> { $0.bio.contains("hell") }
        let bioContainsFilter = try notionFilter(bioContainsPredicate)
        check(
            bioContainsFilter == .richText("Bio", .contains("hell")),
            "predicate rich text contains converts"
        )
        check(
            encodedFilter(bioContainsFilter) == normalizedJSON(["property": "Bio", "rich_text": ["contains": "hell"]]),
            "predicate-derived rich text contains filter encodes to Notion shape"
        )

        let factoryBioContainsFilter: NotionFilter = try .predicate(bioContainsPredicate)
        check(
            factoryBioContainsFilter == bioContainsFilter,
            "NotionFilter.predicate factory agrees with notionFilter for rich text contains"
        )

        let negatedBioContainsPredicate = #Predicate<ArtistDTO> { !$0.bio.contains("hell") }
        check(
            try notionFilter(negatedBioContainsPredicate) == .richText("Bio", .doesNotContain("hell")),
            "negated rich text contains converts to does_not_contain"
        )

        let titleContainsPredicate = #Predicate<ArtistDTO> { $0.name.contains("Art") }
        check(
            try notionFilter(titleContainsPredicate) == .title("Nome", .contains("Art")),
            "predicate title contains converts"
        )

        let titleStartsWithPredicate = #Predicate<ArtistDTO> { $0.name.starts(with: "Art") }
        let titleStartsWithFilter = try notionFilter(titleStartsWithPredicate)
        check(
            titleStartsWithFilter == .title("Nome", .startsWith("Art")),
            "predicate title starts-with converts"
        )
        check(
            encodedFilter(titleStartsWithFilter) == normalizedJSON(["property": "Nome", "title": ["starts_with": "Art"]]),
            "predicate-derived title starts-with filter encodes to Notion shape"
        )

        let bioStartsWithPredicate = #Predicate<ArtistDTO> { $0.bio.starts(with: "Bio") }
        check(
            try notionFilter(bioStartsWithPredicate) == .richText("Bio", .startsWith("Bio")),
            "predicate rich text starts-with converts"
        )

        do {
            _ = try notionFilter(#Predicate<ArtistDTO> { !$0.name.starts(with: "Art") })
            check(false, "negated starts-with rejects as not expressible")
        } catch NotionFilterConversionError.unsupportedRoot {
            check(true, "negated starts-with rejects as unsupportedRoot")
        }

        do {
            let extraURL = URL(string: "https://example.com/extra1.jpg")!
            _ = try notionFilter(#Predicate<ArtDTO> { $0.extraPhotoURLs.contains(extraURL) })   // files, not relation
            check(false, "non-relation sequence contains rejects")
        } catch NotionFilterConversionError.unsupportedRoot {
            check(true, "non-relation sequence contains rejects as unsupportedRoot")
        }

        let emptyFilesPredicate = #Predicate<ArtDTO> { $0.extraPhotoURLs.isEmpty }
        let emptyFilesFilter = try notionFilter(emptyFilesPredicate)
        check(
            emptyFilesFilter == .files("Fotos Extras", .isEmpty),
            "predicate files isEmpty converts"
        )
        check(
            encodedFilter(emptyFilesFilter) == normalizedJSON(["property": "Fotos Extras", "files": ["is_empty": true]]),
            "predicate-derived files isEmpty filter encodes"
        )

        let nonEmptyFilesPredicate = #Predicate<ArtDTO> { !$0.extraPhotoURLs.isEmpty }
        let nonEmptyFilesFilter = try notionFilter(nonEmptyFilesPredicate)
        check(
            nonEmptyFilesFilter == .files("Fotos Extras", .isNotEmpty),
            "negated files isEmpty converts to is_not_empty"
        )
        check(
            encodedFilter(nonEmptyFilesFilter) == normalizedJSON(["property": "Fotos Extras", "files": ["is_not_empty": true]]),
            "negated predicate-derived files filter encodes"
        )

        let nilFilePredicate = #Predicate<ArtDTO> { $0.mainPhotoURL == nil }
        let nilFileFilter = try notionFilter(nilFilePredicate)
        check(
            nilFileFilter == .files("Foto Principal", .isEmpty),
            "file == nil converts to files is_empty"
        )
        check(
            encodedFilter(nilFileFilter) == normalizedJSON(["property": "Foto Principal", "files": ["is_empty": true]]),
            "predicate-derived file == nil filter encodes"
        )

        let nonNilFilePredicate = #Predicate<ArtDTO> { $0.mainPhotoURL != nil }
        let nonNilFileFilter = try notionFilter(nonNilFilePredicate)
        check(
            nonNilFileFilter == .files("Foto Principal", .isNotEmpty),
            "file != nil converts to files is_not_empty"
        )
        check(
            encodedFilter(nonNilFileFilter) == normalizedJSON(["property": "Foto Principal", "files": ["is_not_empty": true]]),
            "predicate-derived file != nil filter encodes"
        )

        let negatedNilFilePredicate = #Predicate<ArtDTO> { !($0.mainPhotoURL == nil) }
        check(
            try notionFilter(negatedNilFilePredicate) == .files("Foto Principal", .isNotEmpty),
            "negated file == nil converts to is_not_empty"
        )

        do {
            let someURL = URL(string: "https://example.com/main.jpg")!
            _ = try notionFilter(#Predicate<ArtDTO> { $0.mainPhotoURL == someURL })
            check(false, "file URL equality rejects")
        } catch NotionFilterConversionError.unsupportedRoot {
            check(true, "file URL equality rejects as unsupportedRoot")
        }

        do {
            let extraURL = URL(string: "https://example.com/extra1.jpg")!
            _ = try NotionFilter.predicate(#Predicate<ArtDTO> { $0.extraPhotoURLs.contains(extraURL) })
            check(false, "factory propagates conversion errors")
        } catch NotionFilterConversionError.unsupportedRoot {
            check(true, "factory propagates conversion errors as unsupportedRoot")
        }
    }

    let feedback = try JSONDecoder().decode(FeedbackDTO.self, from: feedbackJSON)
    check(feedback.published == true, "checkbox decodes to Bool")
    check(feedback.score == 8, "number decodes to Double?")
    check(feedback.weight == 1.5, "@NotionProperty Double? infers number")
    check(feedback.active == true, "@NotionProperty Bool infers checkbox")
    check(FeedbackDTO.notionProperties[\.published] == NotionField(name: "Publicado", kind: .checkbox), "checkbox keypath maps to field")
    check(FeedbackDTO.notionProperties[\.score] == NotionField(name: "Nota", kind: .number), "number keypath maps to field")
    check(FeedbackDTO.notionProperties[\.weight] == NotionField(name: "Peso", kind: .number), "inferred number keypath maps to field")
    check(FeedbackDTO.notionProperties[\.active] == NotionField(name: "Ativo", kind: .checkbox), "inferred checkbox keypath maps to field")

    let emptyFeedback = try JSONDecoder().decode(FeedbackDTO.self, from: feedbackEmptyNumberJSON)
    check(emptyFeedback.published == false, "missing checkbox falls back to false")
    check(emptyFeedback.score == nil, "null number decodes to nil")
    check(emptyFeedback.active == false, "explicit false checkbox decodes")

    let encodedFeedback = normalizedJSON(try JSONSerialization.jsonObject(with: JSONEncoder().encode(feedback)))
    check(
        encodedFeedback == normalizedJSON([
            "properties": [
                "Nome": ["title": [["type": "text", "text": ["content": "Feedback"]]]],
                "Publicado": ["checkbox": true],
                "Nota": ["number": 8],
                "Peso": ["number": 1.5],
                "Ativo": ["checkbox": true],
            ] as [String: Any],
        ]),
        "feedback encodes checkbox and number in Notion shape"
    )

    let encodedEmptyFeedback = try JSONSerialization.jsonObject(with: JSONEncoder().encode(emptyFeedback)) as! [String: Any]
    let encodedEmptyFeedbackProperties = encodedEmptyFeedback["properties"] as! [String: Any]
    check(encodedEmptyFeedbackProperties["Nota"] == nil, "nil number property is omitted")
    check(encodedEmptyFeedbackProperties["Peso"] == nil, "nil inferred number property is omitted")
    check((encodedEmptyFeedbackProperties["Ativo"] as? [String: Any])?["checkbox"] as? Bool == false, "explicit false checkbox still encodes")


    print("OK")
} catch {
    print("FAIL: \(error)")
    exit(1)
}
