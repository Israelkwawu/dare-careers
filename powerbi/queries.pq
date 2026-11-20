// Dare Careers learner progress
// Paste each block into its own blank query, in this order.
// The query name is the first line of the block.
// Enable load only for: DimCohort, DimLearner, DimProgramWeek, DimDate,
// AsOfWeek, FactAttendance, FactParticipation, FactAssessment,
// DataExceptions, FeedCheck, RuleBook.
// Leave fn, qFiles, and every stg query as connection-only.
//
// Before the first query: Home > Manage Parameters > New.
// Name: pIntakeRoot. Type: Text. Required.
// Current value: C:\DataEngineering\dare-careers
// That folder contains the intake folders. It is not the intake folder itself.

// =============================================================================
// fn
// =============================================================================
[
    NormalizeEmail = (e as any) as nullable text =>
        let
            t = if e = null then null else Text.Lower(Text.Trim(Text.From(e)))
        in
            if t = null or t = "" then null else t,
    NormalizeName = (n as any) as nullable text =>
        let
            t = if n = null then null else Text.Trim(Text.From(n)),
            parts = if t = null or t = "" then {} else List.Select(Text.Split(t, " "), each _ <> "")
        in
            if List.Count(parts) = 0 then null else Text.Lower(Text.Combine(parts, " ")),
    DurationMinutes = (dur as any) as nullable number =>
        let
            t = if dur = null then "" else Text.Trim(Text.From(dur)),
            result =
                if t = "" or Text.Lower(t) = "null" then
                    null
                else if Text.Contains(t, ":") then
                    let
                        raw = List.Transform(Text.Split(t, ":"), each try Number.FromText(Text.Trim(_)) otherwise null),
                        bad = List.AnyTrue(List.Transform(raw, each _ = null)),
                        mins =
                            if bad then
                                null
                            else if List.Count(raw) = 3 then
                                raw{0} * 60 + raw{1} + raw{2} / 60
                            else if List.Count(raw) = 2 then
                                raw{0} + raw{1} / 60
                            else
                                null
                    in
                        mins
                else
                    try Number.FromText(t) otherwise try Number.From(dur) otherwise null
        in
            result,
    ParseClassDate = (v as any) as nullable date =>
        if v = null then
            null
        else if Value.Is(v, type date) then
            Date.From(v)
        else if Value.Is(v, type datetime) then
            Date.From(v)
        else if Value.Is(v, type datetimezone) then
            Date.From(v)
        else if Value.Is(v, type number) then
            try Date.From(v) otherwise null
        else
            let
                t = Text.Trim(Text.From(v)),
                fromName = try Date.FromText(t, [Format = "dd-MMM-yyyy", Culture = "en-US"]) otherwise null,
                fromCulture = if fromName <> null then fromName else try Date.FromText(t, [Culture = "en-US"]) otherwise null
            in
                fromCulture,
    WeekFromLabel = (label as any) as nullable number =>
        let
            t = if label = null then "" else Text.Trim(Text.From(label)),
            last = if t = "" then null else List.Last(Text.Split(t, " "))
        in
            if t = "" then null else try Int64.From(Number.FromText(last)) otherwise null,
    TrimHeaders = (tbl as table) as table =>
        Table.RenameColumns(tbl, List.Transform(Table.ColumnNames(tbl), each {_, Text.Trim(_)}), MissingField.Ignore),
    PickColumn = (tbl as table, wanted as text) as nullable text =>
        let
            hits = List.Select(Table.ColumnNames(tbl), each Text.Lower(Text.Trim(_)) = Text.Lower(wanted))
        in
            if List.Count(hits) = 0 then null else hits{0},
    ReadExcel = (content as binary) as table =>
        let
            wb = Excel.Workbook(content, true, true),
            sheets = Table.SelectRows(wb, each [Kind] = "Sheet" or [Kind] = "Table")
        in
            Table.SelectColumns(sheets, {"Name", "Data"}),
    TrackName = (folder as any) as nullable text =>
        let
            t = if folder = null then "" else Text.Trim(Text.From(folder)),
            raw = if Text.EndsWith(t, " Training") then Text.BeforeDelimiter(t, " Training") else t
        in
            if raw = "" then null else if raw = "PowerBI" then "Power BI" else raw,
    DisplayFromEmail = (email as any) as nullable text =>
        let
            e = if email = null then null else Text.From(email),
            local = if e = null or not Text.Contains(e, "@") then e else Text.BeforeDelimiter(e, "@"),
            spaced = if local = null then null else Text.Trim(Text.Replace(Text.Replace(local, ".", " "), "_", " "))
        in
            if spaced = null or spaced = "" then null else Text.Proper(spaced)
]

// =============================================================================
// qFiles
// =============================================================================
let
    Source = Folder.Files(pIntakeRoot),
    NoLock = Table.SelectRows(Source, each not Text.StartsWith([Name], "~$")),
    KeepExt = Table.SelectRows(NoLock, each List.Contains({".csv", ".xlsx", ".xls"}, Text.Lower([Extension]))),
    AddParts = Table.AddColumn(KeepExt, "Parts", each List.RemoveItems(Text.Split(Text.Replace([Folder Path], "/", "\"), "\"), {""}), type list),
    AddMeta = Table.AddColumn(AddParts, "Meta", each
        let
            parts = [Parts],
            n = List.Count(parts),
            immediate = if n < 1 then null else parts{n - 1},
            parent = if n < 2 then null else parts{n - 2},
            grand = if n < 3 then null else parts{n - 3},
            great = if n < 4 then null else parts{n - 4},
            isWeek = immediate <> null and Text.StartsWith(Text.Lower(immediate), "week"),
            feedFolder = if isWeek then parent else immediate,
            feedText = if feedFolder = null then "" else Text.Lower(feedFolder),
            feed =
                if Text.Contains(feedText, "zoom") or Text.Contains(feedText, "attendance") then "Attendance"
                else if Text.Contains(feedText, "participation") then "Participation"
                else if Text.Contains(feedText, "lab") then "Assessment"
                else if Text.Contains(feedText, "status") then "Status"
                else null,
            week = if isWeek then fn[WeekFromLabel](immediate) else null
        in
            [
                FeedKey = feed,
                CohortKey = if isWeek then great else grand,
                Track = fn[TrackName](if isWeek then grand else parent),
                WeekNumber = week,
                FolderPath = [Folder Path]
            ]
    ),
    Expanded = Table.ExpandRecordColumn(AddMeta, "Meta", {"FeedKey", "CohortKey", "Track", "WeekNumber", "FolderPath"}),
    Scoped = Table.SelectRows(Expanded, each [FeedKey] <> null and [CohortKey] <> null and [Track] <> null),
    Slim = Table.SelectColumns(Scoped, {"Content", "Name", "Extension", "FeedKey", "CohortKey", "Track", "WeekNumber", "FolderPath"})
in
    Table.Buffer(Slim)

// =============================================================================
// stgAttendance
// One row per live-class file row. Role, email, date, and duration checked.
// =============================================================================
let
    Files = Table.SelectRows(qFiles, each [FeedKey] = "Attendance" and Text.Lower([Extension]) = ".csv"),
    Empty = #table(
        type table [
            CohortKey = text, Track = text, WeekFromFolder = Int64.Type, ClassDate = date,
            Email = text, LearnerName = text, DurationMinutes = number, SourceFile = text, RowUse = text
        ],
        {}
    ),
    ReadOne = (row as record) as table =>
        let
            csv = Csv.Document(row[Content], [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
            promoted = fn[TrimHeaders](Table.PromoteHeaders(csv, [PromoteAllScalars = true])),
            cName = fn[PickColumn](promoted, "Name"),
            cEmail = fn[PickColumn](promoted, "Email"),
            cDur = fn[PickColumn](promoted, "Duration"),
            cRole = fn[PickColumn](promoted, "Role"),
            classDate = fn[ParseClassDate](Text.BeforeDelimiter(row[Name], ".")),
            sourceFile = row[FolderPath] & row[Name],
            shaped =
                if cEmail = null or cDur = null then
                    error "Live-class file is missing Email or Duration: " & sourceFile
                else
                    let
                        selected = Table.SelectColumns(promoted, List.RemoveNulls({cName, cEmail, cDur, cRole})),
                        renamed = Table.RenameColumns(
                            selected,
                            List.RemoveNulls({
                                if cName = null then null else {cName, "LearnerName"},
                                {cEmail, "Email"},
                                {cDur, "DurationRaw"},
                                if cRole = null then null else {cRole, "Role"}
                            })
                        ),
                        withName = if Table.HasColumns(renamed, "LearnerName") then renamed else Table.AddColumn(renamed, "LearnerName", each null, type text),
                        withRole = if Table.HasColumns(withName, "Role") then withName else Table.AddColumn(withName, "Role", each "Participant", type text)
                    in
                        withRole,
            tagged = Table.AddColumn(shaped, "CohortKey", each row[CohortKey], type text),
            tagged2 = Table.AddColumn(tagged, "Track", each row[Track], type text),
            tagged3 = Table.AddColumn(tagged2, "WeekFromFolder", each row[WeekNumber], Int64.Type),
            tagged4 = Table.AddColumn(tagged3, "ClassDate", each classDate, type date),
            tagged5 = Table.AddColumn(tagged4, "SourceFile", each sourceFile, type text)
        in
            tagged5,
    Combined = if Table.IsEmpty(Files) then null else Table.Combine(List.Transform(Table.ToRecords(Files), each ReadOne(_))),
    AddEmail = if Combined = null then null else Table.AddColumn(Combined, "EmailKey", each fn[NormalizeEmail](try [Email] otherwise null), type text),
    AddMinutes = Table.AddColumn(AddEmail, "DurationMinutes", each fn[DurationMinutes](try [DurationRaw] otherwise null), type number),
    AddUse = Table.AddColumn(AddMinutes, "RowUse", each
        let
            role = if [Role] = null then "" else Text.Lower(Text.Trim(Text.From([Role]))),
            roleOk = role = "" or role = "participant",
            raw = if [DurationRaw] = null then "" else Text.Trim(Text.From([DurationRaw]))
        in
            if not roleOk then "Not a learner"
            else if [EmailKey] = null or [ClassDate] = null then "No identity"
            else if raw <> "" and [DurationMinutes] = null then "Bad duration"
            else "Keep",
        type text
    ),
    Renamed = Table.RenameColumns(AddUse, {{"EmailKey", "EmailNorm"}}),
    Projected = if AddEmail = null then Empty else Table.SelectColumns(Renamed, {"CohortKey", "Track", "WeekFromFolder", "ClassDate", "EmailNorm", "LearnerName", "DurationMinutes", "SourceFile", "RowUse"})
in
    if AddEmail = null then Empty else Table.RenameColumns(Projected, {{"EmailNorm", "Email"}})

// =============================================================================
// stgAttendanceDay
// One row per learner per class day. Rejoins are summed, then the 30-minute test can be applied later.
// =============================================================================
let
    Keep = Table.SelectRows(stgAttendance, each [RowUse] = "Keep" or [RowUse] = "Bad duration"),
    Grouped = Table.Group(
        Keep,
        {"CohortKey", "Track", "Email", "ClassDate"},
        {
            {"WeekFromFolder", each List.Min(List.RemoveNulls([WeekFromFolder])), Int64.Type},
            {"WeekChoices", each List.Count(List.Distinct(List.RemoveNulls([WeekFromFolder]))), Int64.Type},
            {"DurationMinutes", each List.Sum(List.RemoveNulls([DurationMinutes])), type number},
            {"LearnerName", each let ns = List.RemoveNulls([LearnerName]) in if List.IsEmpty(ns) then null else ns{0}, type text},
            {"SourceFile", each let ns = List.RemoveNulls([SourceFile]) in if List.IsEmpty(ns) then null else ns{0}, type text}
        }
    )
in
    Grouped

// =============================================================================
// stgParticipation
// One row per name token per participation date.
// =============================================================================
let
    Files = Table.SelectRows(qFiles, each [FeedKey] = "Participation" and (Text.Lower([Extension]) = ".xlsx" or Text.Lower([Extension]) = ".xls")),
    Empty = #table(
        type table [CohortKey = text, Track = text, ClassDate = date, RawName = text, NameKey = text, SourceFile = text, DateProblem = text],
        {}
    ),
    ReadOne = (row as record) as table =>
        let
            sheets = fn[ReadExcel](row[Content]),
            sourceFile = row[FolderPath] & row[Name],
            ReadSheet = (sheet as record) as table =>
                let
                    data = fn[TrimHeaders](sheet[Data]),
                    cDate = fn[PickColumn](data, "Date"),
                    cPeople = fn[PickColumn](data, "Participants"),
                    emptySheet = #table(type table [CohortKey = text, Track = text, ClassDate = date, RawName = text, NameKey = text, SourceFile = text, DateProblem = text], {}),
                    out =
                        if cDate = null or cPeople = null then
                            emptySheet
                        else
                            let
                                projected = Table.RenameColumns(Table.SelectColumns(data, {cDate, cPeople}), {{cDate, "DateRaw"}, {cPeople, "PeopleRaw"}}),
                                dated = Table.AddColumn(projected, "ClassDate", each fn[ParseClassDate]([DateRaw]), type date),
                                marked = Table.AddColumn(dated, "DateProblem", each if [DateRaw] = null or Text.Trim(Text.From([DateRaw])) = "" then null else if [ClassDate] = null then "Participation date could not be read" else null, type text),
                                split = Table.AddColumn(marked, "Token", each
                                    let
                                        raw = if [PeopleRaw] = null then {} else Text.Split(Text.From([PeopleRaw]), ","),
                                        cleaned = List.Select(List.Transform(raw, each Text.Trim(_)), each _ <> "")
                                    in
                                        cleaned,
                                    type list
                                ),
                                expanded = Table.ExpandListColumn(split, "Token"),
                                named = Table.AddColumn(expanded, "RawName", each if [Token] = null or [Token] = "" then null else [Token], type text),
                                keyed = Table.AddColumn(named, "NameKey", each fn[NormalizeName]([RawName]), type text),
                                tagged = Table.AddColumn(keyed, "CohortKey", each row[CohortKey], type text),
                                tagged2 = Table.AddColumn(tagged, "Track", each row[Track], type text),
                                tagged3 = Table.AddColumn(tagged2, "SourceFile", each sourceFile, type text),
                                kept = Table.SelectRows(tagged3, each [RawName] <> null or [DateProblem] <> null)
                            in
                                Table.SelectColumns(kept, {"CohortKey", "Track", "ClassDate", "RawName", "NameKey", "SourceFile", "DateProblem"})
                in
                    out,
            stacked = if Table.IsEmpty(sheets) then #table(type table [CohortKey = text, Track = text, ClassDate = date, RawName = text, NameKey = text, SourceFile = text, DateProblem = text], {}) else Table.Combine(List.Transform(Table.ToRecords(sheets), each ReadSheet(_)))
        in
            stacked,
    Combined = if Table.IsEmpty(Files) then Empty else Table.Combine(List.Transform(Table.ToRecords(Files), each ReadOne(_)))
in
    Table.SelectRows(Combined, each [RawName] <> null or [DateProblem] <> null)

// =============================================================================
// stgAssessment
// One row per learner per week per lab or quiz column.
// =============================================================================
let
    Files = Table.SelectRows(qFiles, each [FeedKey] = "Assessment" and (Text.Lower([Extension]) = ".xlsx" or Text.Lower([Extension]) = ".xls")),
    Empty = #table(
        type table [CohortKey = text, Track = text, Email = text, WeekNumber = Int64.Type, AssessmentType = text, Score = number, ScoreProblem = text, SourceFile = text],
        {}
    ),
    ReadOne = (row as record) as table =>
        let
            sheets = fn[ReadExcel](row[Content]),
            sourceFile = row[FolderPath] & row[Name],
            blank = #table(type table [CohortKey = text, Track = text, Email = text, WeekNumber = Int64.Type, AssessmentType = text, Score = number, ScoreProblem = text, SourceFile = text], {}),
            ReadSheet = (sheet as record) as table =>
                let
                    data = fn[TrimHeaders](sheet[Data]),
                    cEmail = fn[PickColumn](data, "Email"),
                    weekCols = List.Select(Table.ColumnNames(data), each Text.StartsWith(Text.Lower(Text.Trim(_)), "week")),
                    kindText = Text.Lower(Text.From(sheet[Name])),
                    kind = if Text.Contains(kindText, "quiz") then "Quiz" else if Text.Contains(kindText, "lab") then "Lab" else null,
                    emptySheet = #table(type table [CohortKey = text, Track = text, Email = text, WeekNumber = Int64.Type, AssessmentType = text, Score = number, ScoreProblem = text, SourceFile = text], {}),
                    out =
                        if cEmail = null or List.IsEmpty(weekCols) or kind = null then
                            emptySheet
                        else
                            let
                                slim = Table.SelectColumns(data, List.Combine({{cEmail}, weekCols})),
                                renamed = Table.RenameColumns(slim, {{cEmail, "Email"}}),
                                unpivoted = Table.Unpivot(renamed, weekCols, "WeekLabel", "ScoreRaw"),
                                typed = Table.AddColumn(unpivoted, "EmailKey", each fn[NormalizeEmail]([Email]), type text),
                                weeked = Table.AddColumn(typed, "WeekNumber", each fn[WeekFromLabel]([WeekLabel]), Int64.Type),
                                scored = Table.AddColumn(weeked, "Score", each
                                    if [ScoreRaw] = null then null
                                    else if Value.Is([ScoreRaw], type number) then Number.From([ScoreRaw])
                                    else if Text.Trim(Text.From([ScoreRaw])) = "" then null
                                    else try Number.FromText(Text.Trim(Text.From([ScoreRaw]))) otherwise null,
                                    type number
                                ),
                                problem = Table.AddColumn(scored, "ScoreProblem", each
                                    if [Score] = null then
                                        if [ScoreRaw] = null then null
                                        else if Text.Trim(Text.From([ScoreRaw])) = "" then null
                                        else "Assessment score could not be read"
                                    else
                                        null,
                                    type text
                                ),
                                tagged = Table.AddColumn(problem, "CohortKey", each row[CohortKey], type text),
                                tagged2 = Table.AddColumn(tagged, "Track", each row[Track], type text),
                                tagged3 = Table.AddColumn(tagged2, "AssessmentType", each kind, type text),
                                tagged4 = Table.AddColumn(tagged3, "SourceFile", each sourceFile, type text)
                            in
                                Table.SelectColumns(tagged4, {"CohortKey", "Track", "EmailKey", "WeekNumber", "AssessmentType", "Score", "ScoreProblem", "SourceFile"})
                in
                    if Table.HasColumns(out, "EmailKey") then Table.RenameColumns(out, {{"EmailKey", "Email"}}) else out,
            stacked = if Table.IsEmpty(sheets) then blank else Table.Combine(List.Transform(Table.ToRecords(sheets), each ReadSheet(_)))
        in
            stacked,
    Combined = if Table.IsEmpty(Files) then Empty else Table.Combine(List.Transform(Table.ToRecords(Files), each ReadOne(_)))
in
    Table.SelectRows(Combined, each [Email] <> null and ([WeekNumber] <> null or [ScoreProblem] <> null))

// =============================================================================
// stgStatus
// =============================================================================
let
    Files = Table.SelectRows(qFiles, each [FeedKey] = "Status" and (Text.Lower([Extension]) = ".xlsx" or Text.Lower([Extension]) = ".xls")),
    Empty = #table(type table [CohortKey = text, Track = text, Email = text, GraduationStatus = text, CertificationStatus = text, SourceFile = text], {}),
    ReadOne = (row as record) as table =>
        let
            sheets = fn[ReadExcel](row[Content]),
            sourceFile = row[FolderPath] & row[Name],
            ReadSheet = (sheet as record) as table =>
                let
                    data = fn[TrimHeaders](sheet[Data]),
                    cEmail = fn[PickColumn](data, "Email"),
                    gradHits = List.Select(Table.ColumnNames(data), each Text.Contains(Text.Lower(_), "graduation")),
                    certHits = List.Select(Table.ColumnNames(data), each Text.Contains(Text.Lower(_), "certification")),
                    emptySheet = #table(type table [CohortKey = text, Track = text, Email = text, GraduationStatus = text, CertificationStatus = text, SourceFile = text], {}),
                    out =
                        if cEmail = null or List.IsEmpty(gradHits) then
                            emptySheet
                        else
                            let
                                cGrad = gradHits{0},
                                cCert = if List.IsEmpty(certHits) then null else certHits{0},
                                cols = List.RemoveNulls({cEmail, cGrad, cCert}),
                                slim = Table.SelectColumns(data, cols),
                                renamed = Table.RenameColumns(slim, List.RemoveNulls({{cEmail, "Email"}, {cGrad, "GraduationStatus"}, if cCert = null then null else {cCert, "CertificationStatus"}})),
                                withCert = if Table.HasColumns(renamed, "CertificationStatus") then renamed else Table.AddColumn(renamed, "CertificationStatus", each null, type text),
                                cleaned = Table.AddColumn(withCert, "EmailKey", each fn[NormalizeEmail]([Email]), type text),
                                tagged = Table.AddColumn(cleaned, "CohortKey", each row[CohortKey], type text),
                                tagged2 = Table.AddColumn(tagged, "Track", each row[Track], type text),
                                tagged3 = Table.AddColumn(tagged2, "SourceFile", each sourceFile, type text),
                                kept = Table.SelectRows(tagged3, each [EmailKey] <> null)
                            in
                                Table.RenameColumns(Table.SelectColumns(kept, {"CohortKey", "Track", "EmailKey", "GraduationStatus", "CertificationStatus", "SourceFile"}), {{"EmailKey", "Email"}})
                in
                    out,
            stacked = if Table.IsEmpty(sheets) then #table(type table [CohortKey = text, Track = text, Email = text, GraduationStatus = text, CertificationStatus = text, SourceFile = text], {}) else Table.Combine(List.Transform(Table.ToRecords(sheets), each ReadSheet(_)))
        in
            stacked,
    Combined = if Table.IsEmpty(Files) then Empty else Table.Combine(List.Transform(Table.ToRecords(Files), each ReadOne(_)))
in
    Combined

// =============================================================================
// stgCohortAnchor
// Monday on or before the first class date in each intake folder.
// =============================================================================
let
    AttDates = Table.SelectColumns(Table.SelectRows(stgAttendanceDay, each [ClassDate] <> null), {"CohortKey", "ClassDate"}),
    PartDates = Table.SelectColumns(Table.SelectRows(stgParticipation, each [ClassDate] <> null), {"CohortKey", "ClassDate"}),
    Both = Table.Distinct(Table.Combine({AttDates, PartDates})),
    Grouped = Table.Group(Both, {"CohortKey"}, {{"FirstClass", each List.Min([ClassDate]), type date}}),
    Monday = Table.AddColumn(Grouped, "StartMonday", each Date.AddDays([FirstClass], - Date.DayOfWeek([FirstClass], Day.Monday)), type date)
in
    Monday

// =============================================================================
// DimCohort
// =============================================================================
let
    AttDates = Table.SelectColumns(Table.SelectRows(stgAttendanceDay, each [ClassDate] <> null), {"CohortKey", "ClassDate"}),
    PartDates = Table.SelectColumns(Table.SelectRows(stgParticipation, each [ClassDate] <> null), {"CohortKey", "ClassDate"}),
    Both = Table.Distinct(Table.Combine({AttDates, PartDates})),
    Grouped = Table.Group(
        Both,
        {"CohortKey"},
        {
            {"StartDate", each List.Min([ClassDate]), type date},
            {"EndDate", each List.Max([ClassDate]), type date}
        }
    ),
    Labeled = Table.AddColumn(Grouped, "BaseLabel", each Date.ToText([StartDate], "MMM yyyy", "en-US") & " intake", type text),
    Counts = Table.Group(Labeled, {"BaseLabel"}, {{"LabelCount", each Table.RowCount(_), Int64.Type}}),
    Joined = Table.NestedJoin(Labeled, {"BaseLabel"}, Counts, {"BaseLabel"}, "C", JoinKind.LeftOuter),
    Expanded = Table.ExpandTableColumn(Joined, "C", {"LabelCount"}),
    Named = Table.AddColumn(Expanded, "CohortName", each if [LabelCount] > 1 then [BaseLabel] & " (" & [CohortKey] & ")" else [BaseLabel], type text),
    Result = Table.SelectColumns(Named, {"CohortKey", "CohortName", "StartDate", "EndDate"})
in
    Table.Sort(Result, {{"StartDate", Order.Ascending}})

// =============================================================================
// DimLearner
// =============================================================================
let
    FromAtt = Table.Group(
        Table.SelectRows(stgAttendanceDay, each [Email] <> null),
        {"CohortKey", "Track", "Email"},
        {{"LearnerName", each let ns = List.RemoveNulls([LearnerName]) in if List.IsEmpty(ns) then null else ns{0}, type text}}
    ),
    FromAss = Table.Distinct(Table.SelectColumns(Table.SelectRows(stgAssessment, each [Email] <> null), {"CohortKey", "Track", "Email"})),
    FromAssNamed = Table.AddColumn(FromAss, "LearnerName", each null, type text),
    FromStat = Table.Distinct(Table.SelectColumns(Table.SelectRows(stgStatus, each [Email] <> null), {"CohortKey", "Track", "Email"})),
    FromStatNamed = Table.AddColumn(FromStat, "LearnerName", each null, type text),
    Stacked = Table.Combine({FromAtt, FromAssNamed, FromStatNamed}),
    Named = Table.Group(
        Stacked,
        {"CohortKey", "Track", "Email"},
        {{"LearnerName", each
            let
                sub = _,
                ns = List.RemoveNulls(sub[LearnerName]),
                email = List.First(sub[Email])
            in
                if List.IsEmpty(ns) then fn[DisplayFromEmail](email) else List.First(ns),
            type text}}
    ),
    StatusSlim = Table.SelectColumns(stgStatus, {"CohortKey", "Track", "Email", "GraduationStatus", "CertificationStatus"}),
    WithStatus = Table.NestedJoin(Named, {"CohortKey", "Track", "Email"}, StatusSlim, {"CohortKey", "Track", "Email"}, "S", JoinKind.LeftOuter),
    Expanded = Table.ExpandTableColumn(WithStatus, "S", {"GraduationStatus", "CertificationStatus"}),
    WithCohort = Table.NestedJoin(Expanded, {"CohortKey"}, DimCohort, {"CohortKey"}, "C", JoinKind.LeftOuter),
    WithName = Table.ExpandTableColumn(WithCohort, "C", {"CohortName"}),
    Keyed = Table.AddColumn(WithName, "LearnerKey", each [CohortKey] & "|" & [Email], type text),
    NameKey = Table.AddColumn(Keyed, "NameKey", each fn[NormalizeName]([LearnerName]), type text),
    Result = Table.SelectColumns(NameKey, {"LearnerKey", "CohortKey", "CohortName", "Track", "Email", "LearnerName", "NameKey", "GraduationStatus", "CertificationStatus"})
in
    Table.Sort(Table.Distinct(Result, {"LearnerKey"}), {{"CohortName", Order.Ascending}, {"Track", Order.Ascending}, {"LearnerName", Order.Ascending}})

// =============================================================================
// stgParticipationMatched
// =============================================================================
let
    Lookup = Table.Group(
        Table.SelectRows(DimLearner, each [NameKey] <> null),
        {"CohortKey", "Track", "NameKey"},
        {
            {"MatchCount", each List.Count(List.Distinct([LearnerKey])), Int64.Type},
            {"LearnerKey", each let keys = List.Distinct([LearnerKey]) in if List.Count(keys) = 1 then keys{0} else null, type text}
        }
    ),
    Joined = Table.NestedJoin(stgParticipation, {"CohortKey", "Track", "NameKey"}, Lookup, {"CohortKey", "Track", "NameKey"}, "L", JoinKind.LeftOuter),
    Expanded = Table.ExpandTableColumn(Joined, "L", {"MatchCount", "LearnerKey"}),
    Status = Table.AddColumn(Expanded, "MatchStatus", each
        if [RawName] = null then "No name"
        else if [MatchCount] = null or [MatchCount] = 0 then "Unmatched"
        else if [MatchCount] > 1 then "Ambiguous"
        else "Matched",
        type text
    )
in
    Status

// =============================================================================
// stgClassWeek
// Class days by feed, with the folder week when the file has one,
// otherwise counted from the intake's first Monday.
// =============================================================================
let
    Att = Table.Group(
        Table.SelectRows(stgAttendanceDay, each [ClassDate] <> null),
        {"CohortKey", "Track", "ClassDate"},
        {
            {"WeekFromFolder", each List.Min(List.RemoveNulls([WeekFromFolder])), Int64.Type},
            {"WeekChoices", each List.Count(List.Distinct(List.RemoveNulls([WeekFromFolder]))), Int64.Type}
        }
    ),
    AttFeed = Table.AddColumn(Att, "Feed", each "Attendance", type text),
    AttMap = Table.Group(
        Table.SelectRows(Att, each [WeekFromFolder] <> null),
        {"CohortKey", "ClassDate"},
        {{"MappedWeek", each List.Min([WeekFromFolder]), Int64.Type}}
    ),
    Part = Table.Distinct(Table.SelectColumns(Table.SelectRows(stgParticipation, each [ClassDate] <> null), {"CohortKey", "Track", "ClassDate"})),
    PartJoin = Table.NestedJoin(Part, {"CohortKey", "ClassDate"}, AttMap, {"CohortKey", "ClassDate"}, "M", JoinKind.LeftOuter),
    PartExp = Table.ExpandTableColumn(PartJoin, "M", {"MappedWeek"}),
    PartFeed = Table.AddColumn(PartExp, "Feed", each "Participation", type text),
    PartFeed2 = Table.AddColumn(PartFeed, "WeekFromFolder", each [MappedWeek], Int64.Type),
    PartFeed3 = Table.AddColumn(PartFeed2, "WeekChoices", each 1, Int64.Type),
    AttSlim = Table.SelectColumns(AttFeed, {"CohortKey", "Track", "ClassDate", "WeekFromFolder", "WeekChoices", "Feed"}),
    PartSlim = Table.SelectColumns(PartFeed3, {"CohortKey", "Track", "ClassDate", "WeekFromFolder", "WeekChoices", "Feed"}),
    Stacked = Table.Combine({AttSlim, PartSlim}),
    Anchored = Table.NestedJoin(Stacked, {"CohortKey"}, stgCohortAnchor, {"CohortKey"}, "A", JoinKind.LeftOuter),
    AnchorExp = Table.ExpandTableColumn(Anchored, "A", {"StartMonday"}),
    Filled = Table.AddColumn(AnchorExp, "FallbackWeek", each
        if [ClassDate] = null or [StartMonday] = null then null
        else Int64.From(1 + Number.IntegerDivide(Duration.Days([ClassDate] - [StartMonday]), 7)),
        Int64.Type
    ),
    Week = Table.AddColumn(Filled, "WeekNumber", each if [WeekFromFolder] <> null then [WeekFromFolder] else [FallbackWeek], Int64.Type)
in
    Table.SelectColumns(Week, {"CohortKey", "Track", "ClassDate", "WeekNumber", "WeekChoices", "Feed"})

// =============================================================================
// DimProgramWeek
// =============================================================================
let
    FromDays = Table.SelectColumns(Table.SelectRows(stgClassWeek, each [WeekNumber] <> null), {"CohortKey", "WeekNumber", "ClassDate"}),
    FromAss = Table.AddColumn(Table.Distinct(Table.SelectColumns(Table.SelectRows(stgAssessment, each [WeekNumber] <> null), {"CohortKey", "WeekNumber"})), "ClassDate", each null, type date),
    Stacked = Table.Combine({FromDays, Table.SelectColumns(FromAss, {"CohortKey", "WeekNumber", "ClassDate"})}),
    Grouped = Table.Group(
        Stacked,
        {"CohortKey", "WeekNumber"},
        {
            {"WeekStartDate", each let ds = List.RemoveNulls([ClassDate]) in if List.IsEmpty(ds) then null else List.Min(ds), type date},
            {"WeekEndDate", each let ds = List.RemoveNulls([ClassDate]) in if List.IsEmpty(ds) then null else List.Max(ds), type date}
        }
    ),
    Keyed = Table.AddColumn(Grouped, "ProgramWeekKey", each [CohortKey] & "|" & Text.From([WeekNumber]), type text),
    Labeled = Table.AddColumn(Keyed, "WeekLabel", each "Week " & Text.From([WeekNumber]), type text),
    WithCohort = Table.NestedJoin(Labeled, {"CohortKey"}, DimCohort, {"CohortKey"}, "C", JoinKind.LeftOuter),
    Named = Table.ExpandTableColumn(WithCohort, "C", {"CohortName"})
in
    Table.Sort(Table.SelectColumns(Named, {"ProgramWeekKey", "CohortKey", "CohortName", "WeekNumber", "WeekLabel", "WeekStartDate", "WeekEndDate"}), {{"CohortName", Order.Ascending}, {"WeekNumber", Order.Ascending}})

// =============================================================================
// DimDate
// =============================================================================
let
    Empty = #table(type table [Date = date, Year = Int64.Type, MonthNumber = Int64.Type, MonthName = text, DayOfWeekNumber = Int64.Type, DayName = text], {}),
    Result =
        if Table.IsEmpty(DimCohort) then
            Empty
        else
            let
                Start = List.Min(DimCohort[StartDate]),
                End = List.Max(DimCohort[EndDate]),
                Days = List.Dates(Start, Duration.Days(End - Start) + 1, #duration(1, 0, 0, 0)),
                T = Table.FromList(Days, Splitter.SplitByNothing(), {"Date"}, null, ExtraValues.Error),
                Typed = Table.TransformColumnTypes(T, {{"Date", type date}}),
                AddYear = Table.AddColumn(Typed, "Year", each Date.Year([Date]), Int64.Type),
                AddMonth = Table.AddColumn(AddYear, "MonthNumber", each Date.Month([Date]), Int64.Type),
                AddMonthName = Table.AddColumn(AddMonth, "MonthName", each Date.ToText([Date], "MMMM", "en-US"), type text),
                AddDow = Table.AddColumn(AddMonthName, "DayOfWeekNumber", each Date.DayOfWeek([Date], Day.Monday), Int64.Type),
                AddDay = Table.AddColumn(AddDow, "DayName", each Date.ToText([Date], "dddd", "en-US"), type text)
            in
                AddDay
in
    Result

// =============================================================================
// AsOfWeek
// Disconnected. Do not relate it to anything.
// =============================================================================
let
    Weeks = Table.Distinct(Table.SelectColumns(DimProgramWeek, {"WeekNumber"})),
    Labeled = Table.AddColumn(Weeks, "WeekLabel", each "Week " & Text.From([WeekNumber]), type text)
in
    Table.Sort(Labeled, {{"WeekNumber", Order.Ascending}})

// =============================================================================
// FactAttendance
// Missing from the day's file counts as not attended. More than 30 minutes counts as attended.
// =============================================================================
let
    Days = Table.SelectRows(stgClassWeek, each [Feed] = "Attendance" and [WeekNumber] <> null),
    DaySlim = Table.AddColumn(Table.SelectColumns(Days, {"CohortKey", "Track", "ClassDate", "WeekNumber"}), "CohortTrack", each [CohortKey] & "|" & [Track], type text),
    People = Table.AddColumn(Table.SelectColumns(DimLearner, {"LearnerKey", "CohortKey", "Track", "Email"}), "CohortTrack", each [CohortKey] & "|" & [Track], type text),
    Nested = Table.NestedJoin(DaySlim, {"CohortTrack"}, People, {"CohortTrack"}, "L", JoinKind.LeftOuter),
    Grid = Table.ExpandTableColumn(Nested, "L", {"LearnerKey", "Email"}),
    GridKept = Table.SelectRows(Grid, each [LearnerKey] <> null),
    Actual = Table.SelectColumns(stgAttendanceDay, {"CohortKey", "Track", "Email", "ClassDate", "DurationMinutes"}),
    Joined = Table.NestedJoin(GridKept, {"CohortKey", "Track", "Email", "ClassDate"}, Actual, {"CohortKey", "Track", "Email", "ClassDate"}, "A", JoinKind.LeftOuter),
    Expanded = Table.ExpandTableColumn(Joined, "A", {"DurationMinutes"}),
    Att = Table.AddColumn(Expanded, "Attended", each if [DurationMinutes] = null then 0 else if [DurationMinutes] > 30 then 1 else 0, Int64.Type),
    Keyed = Table.AddColumn(Att, "ProgramWeekKey", each [CohortKey] & "|" & Text.From([WeekNumber]), type text),
    Result = Table.SelectColumns(Keyed, {"LearnerKey", "ProgramWeekKey", "WeekNumber", "ClassDate", "DurationMinutes", "Attended"})
in
    Table.TransformColumnTypes(Result, {{"WeekNumber", Int64.Type}, {"ClassDate", type date}, {"DurationMinutes", type number}, {"Attended", Int64.Type}})

// =============================================================================
// FactParticipation
// =============================================================================
let
    Days = Table.SelectRows(stgClassWeek, each [Feed] = "Participation" and [WeekNumber] <> null),
    DaySlim = Table.AddColumn(Table.SelectColumns(Days, {"CohortKey", "Track", "ClassDate", "WeekNumber"}), "CohortTrack", each [CohortKey] & "|" & [Track], type text),
    People = Table.AddColumn(Table.SelectColumns(DimLearner, {"LearnerKey", "CohortKey", "Track"}), "CohortTrack", each [CohortKey] & "|" & [Track], type text),
    Nested = Table.NestedJoin(DaySlim, {"CohortTrack"}, People, {"CohortTrack"}, "L", JoinKind.LeftOuter),
    Grid = Table.SelectRows(Table.ExpandTableColumn(Nested, "L", {"LearnerKey"}), each [LearnerKey] <> null),
    Hit = Table.Distinct(Table.SelectColumns(Table.SelectRows(stgParticipationMatched, each [MatchStatus] = "Matched" and [LearnerKey] <> null and [ClassDate] <> null), {"LearnerKey", "ClassDate"})),
    HitFlag = Table.AddColumn(Hit, "DidParticipate", each 1, Int64.Type),
    Joined = Table.NestedJoin(Grid, {"LearnerKey", "ClassDate"}, HitFlag, {"LearnerKey", "ClassDate"}, "H", JoinKind.LeftOuter),
    Expanded = Table.ExpandTableColumn(Joined, "H", {"DidParticipate"}),
    Flag = Table.AddColumn(Expanded, "Participated", each if [DidParticipate] = null then 0 else [DidParticipate], Int64.Type),
    Keyed = Table.AddColumn(Flag, "ProgramWeekKey", each [CohortKey] & "|" & Text.From([WeekNumber]), type text),
    Result = Table.SelectColumns(Keyed, {"LearnerKey", "ProgramWeekKey", "WeekNumber", "ClassDate", "Participated"})
in
    Table.TransformColumnTypes(Result, {{"WeekNumber", Int64.Type}, {"ClassDate", type date}, {"Participated", Int64.Type}})

// =============================================================================
// FactAssessment
// A blank score stays blank. Zero stays zero.
// =============================================================================
let
    People = Table.SelectColumns(DimLearner, {"LearnerKey", "CohortKey", "Track", "Email"}),
    Joined = Table.NestedJoin(stgAssessment, {"CohortKey", "Track", "Email"}, People, {"CohortKey", "Track", "Email"}, "L", JoinKind.LeftOuter),
    Expanded = Table.ExpandTableColumn(Joined, "L", {"LearnerKey"}),
    Kept = Table.SelectRows(Expanded, each [LearnerKey] <> null and [WeekNumber] <> null),
    Keyed = Table.AddColumn(Kept, "ProgramWeekKey", each [CohortKey] & "|" & Text.From([WeekNumber]), type text),
    Result = Table.SelectColumns(Keyed, {"LearnerKey", "ProgramWeekKey", "WeekNumber", "AssessmentType", "Score"})
in
    Table.TransformColumnTypes(Result, {{"WeekNumber", Int64.Type}, {"Score", type number}})

// =============================================================================
// DataExceptions
// Not related. Measures filter it with TREATAS.
// =============================================================================
let
    Empty = #table(
        type table [CohortKey = text, Track = text, ClassDate = date, WeekNumber = Int64.Type, Email = text, RawName = text, Reason = text, SourceFile = text],
        {}
    ),
    BadAtt = Table.AddColumn(
        Table.SelectRows(stgAttendance, each [RowUse] <> "Keep"),
        "Reason",
        each
            if [RowUse] = "Not a learner" then "Live-class role is not a learner"
            else if [RowUse] = "No identity" then "Live-class row had no email or no class date"
            else "Attendance duration could not be read",
        type text
    ),
    BadAttRows = Table.RenameColumns(
        Table.SelectColumns(BadAtt, {"CohortKey", "Track", "ClassDate", "Email", "LearnerName", "Reason", "SourceFile"}),
        {{"LearnerName", "RawName"}}
    ),
    BadAttWeek = Table.AddColumn(BadAttRows, "WeekNumber", each null, Int64.Type),
    NameProblems = Table.SelectRows(stgParticipationMatched, each [MatchStatus] = "Unmatched" or [MatchStatus] = "Ambiguous" or [DateProblem] <> null),
    NameReason = Table.AddColumn(NameProblems, "Reason", each
        if [DateProblem] <> null and [RawName] = null then [DateProblem]
        else if [MatchStatus] = "Ambiguous" then "Participation name matched more than one learner"
        else if [MatchStatus] = "Unmatched" then "Participation name did not match a learner"
        else [DateProblem],
        type text
    ),
    NameRows = Table.AddColumn(Table.SelectColumns(NameReason, {"CohortKey", "Track", "ClassDate", "RawName", "Reason", "SourceFile"}), "WeekNumber", each null, Int64.Type),
    NameRows2 = Table.AddColumn(NameRows, "Email", each null, type text),
    ScoreProblems = Table.SelectRows(stgAssessment, each [ScoreProblem] <> null),
    ScoreRows = Table.RenameColumns(
        Table.AddColumn(Table.SelectColumns(ScoreProblems, {"CohortKey", "Track", "Email", "WeekNumber", "ScoreProblem", "SourceFile"}), "ClassDate", each null, type date),
        {{"ScoreProblem", "Reason"}}
    ),
    ScoreRows2 = Table.AddColumn(ScoreRows, "RawName", each null, type text),
    WeekClash = Table.SelectRows(stgClassWeek, each [WeekChoices] <> null and [WeekChoices] > 1),
    WeekRows = Table.AddColumn(Table.SelectColumns(WeekClash, {"CohortKey", "Track", "ClassDate", "WeekNumber"}), "Reason", each "The same class date is filed under two weeks", type text),
    WeekRows2 = Table.AddColumn(Table.AddColumn(Table.AddColumn(WeekRows, "Email", each null, type text), "RawName", each null, type text), "SourceFile", each null, type text),
    Columns = {"CohortKey", "Track", "ClassDate", "WeekNumber", "Email", "RawName", "Reason", "SourceFile"},
    Combined = Table.Combine({
        Table.SelectColumns(BadAttWeek, Columns),
        Table.SelectColumns(NameRows2, Columns),
        Table.SelectColumns(ScoreRows2, Columns),
        Table.SelectColumns(WeekRows2, Columns)
    }),
    Result = if Table.IsEmpty(Combined) then Empty else Table.Distinct(Combined)
in
    Result

// =============================================================================
// FeedCheck
// Counts taken before the learner-day grid is built.
// =============================================================================
let
    Att = Table.Group(
        Table.SelectRows(stgAttendanceDay, each [Email] <> null and [ClassDate] <> null),
        {"CohortKey", "Track"},
        {
            {"LearnerCount", each List.Count(List.Distinct([Email])), Int64.Type},
            {"DayOrWeekCount", each List.Count(List.Distinct([ClassDate])), Int64.Type}
        }
    ),
    AttFeed = Table.AddColumn(Att, "Feed", each "Live class", type text),
    Matched = Table.SelectRows(stgParticipationMatched, each [MatchStatus] = "Matched" and [LearnerKey] <> null),
    PartLearners = Table.Group(Matched, {"CohortKey", "Track"}, {{"LearnerCount", each List.Count(List.Distinct([LearnerKey])), Int64.Type}}),
    PartDays = Table.Group(Table.SelectRows(stgParticipation, each [ClassDate] <> null), {"CohortKey", "Track"}, {{"DayOrWeekCount", each List.Count(List.Distinct([ClassDate])), Int64.Type}}),
    PartJoin = Table.NestedJoin(PartDays, {"CohortKey", "Track"}, PartLearners, {"CohortKey", "Track"}, "L", JoinKind.LeftOuter),
    PartExp = Table.ExpandTableColumn(PartJoin, "L", {"LearnerCount"}),
    PartFeed = Table.ReplaceValue(Table.AddColumn(PartExp, "Feed", each "Participation", type text), null, 0, Replacer.ReplaceValue, {"LearnerCount"}),
    Ass = Table.Group(
        stgAssessment,
        {"CohortKey", "Track"},
        {
            {"LearnerCount", each List.Count(List.Distinct([Email])), Int64.Type},
            {"DayOrWeekCount", each List.Count(List.Distinct([WeekNumber])), Int64.Type}
        }
    ),
    AssFeed = Table.AddColumn(Ass, "Feed", each "Assessments", type text),
    Stat = Table.Group(
        stgStatus,
        {"CohortKey", "Track"},
        {
            {"LearnerCount", each List.Count(List.Distinct([Email])), Int64.Type},
            {"DayOrWeekCount", each null, Int64.Type}
        }
    ),
    StatFeed = Table.AddColumn(Stat, "Feed", each "Status", type text),
    Stacked = Table.Combine({
        Table.SelectColumns(AttFeed, {"CohortKey", "Track", "Feed", "LearnerCount", "DayOrWeekCount"}),
        Table.SelectColumns(PartFeed, {"CohortKey", "Track", "Feed", "LearnerCount", "DayOrWeekCount"}),
        Table.SelectColumns(AssFeed, {"CohortKey", "Track", "Feed", "LearnerCount", "DayOrWeekCount"}),
        Table.SelectColumns(StatFeed, {"CohortKey", "Track", "Feed", "LearnerCount", "DayOrWeekCount"})
    })
in
    Stacked

// =============================================================================
// RuleBook
// The Monday page reads this. It is not an input to the call list.
// =============================================================================
#table(
    type table [Signal = text, Bar = text, Applies = text],
    {
        {"In class", "Under 70% of class days. A day counts after more than 30 minutes.", "The last two program weeks"},
        {"Took part", "Under 60% of class days", "The last two program weeks"},
        {"Coursework", "Lab and quiz together under 40", "The last two program weeks"},
        {"Call", "At least two of the three bars missed", "Shown from week 3. Book calls from week 4."}
    }
)
