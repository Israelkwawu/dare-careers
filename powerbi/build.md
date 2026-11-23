# Build the report in Power BI Desktop

The queries, the measures, and the decisions are already written. This is the click path. Import mode. No Premium features.

## 1. Parameter

Home, Manage Parameters, New.

- Name: `pIntakeRoot`
- Type: Text
- Current value: `C:\DataEngineering\dare-careers`

That folder contains `Module 7 Data`. Do not point the parameter at `Module 7 Data` itself. A second intake has to land beside that folder, and the parameter has to see both.

## 2. Queries

Open `powerbi/queries.pq`. Each block is one blank query. The name is the first comment line of the block. Create them in the order they appear. `fn` has to exist before `qFiles`.

Enable load only for:

- `DimCohort`
- `DimLearner`
- `DimProgramWeek`
- `DimDate`
- `AsOfWeek`
- `FactAttendance`
- `FactParticipation`
- `FactAssessment`
- `DataExceptions`
- `FeedCheck`
- `RuleBook`

Right-click every `stg` query, `qFiles`, and `fn`, and turn off Enable load.

Refresh. On this intake the row counts are:

| Table | Rows |
| --- | ---: |
| DimCohort | 1 |
| DimLearner | 140 |
| DimProgramWeek | 10 |
| DimDate | 68 (5 Aug 2024 through 11 Oct 2024) |
| AsOfWeek | 10 |
| FactAttendance | 7,000 |
| FactParticipation | 7,000 |
| FactAssessment | 2,800 |
| DataExceptions | 0 |
| FeedCheck | 8 |
| RuleBook | 4 |

Power BI learners: 100. Cloud: 40. Attendance on Power BI is 100%. Cloud attendance is 1,585 of 2,000 sessions, 79.3%. If Cloud attendance comes out near 0% or near 100%, the duration parse treated both tracks as the same format. Stop and check `fn`.

`DataExceptions` empty is the right result for this drop. It will not stay empty if a later participation name fails to match.

## 3. Model

Mark `DimDate[Date]` as the date table.

Hide `DimLearner[NameKey]`. Hide `WeekNumber` on all three fact tables. Hide `FeedCheck` from the report view if you want; the measures still read it.

Sort `DimProgramWeek[WeekLabel]` by `WeekNumber`. Sort `AsOfWeek[WeekLabel]` by `WeekNumber`. Sort `DimDate[MonthName]` by `MonthNumber`. Sort `DimDate[DayName]` by `DayOfWeekNumber`.

Relationships, all one-to-many, single direction, from the dimension to the fact:

| From | To |
| --- | --- |
| DimCohort[CohortKey] | DimLearner[CohortKey] |
| DimCohort[CohortKey] | FeedCheck[CohortKey] |
| DimLearner[LearnerKey] | FactAttendance[LearnerKey] |
| DimLearner[LearnerKey] | FactParticipation[LearnerKey] |
| DimLearner[LearnerKey] | FactAssessment[LearnerKey] |
| DimProgramWeek[ProgramWeekKey] | FactAttendance[ProgramWeekKey] |
| DimProgramWeek[ProgramWeekKey] | FactParticipation[ProgramWeekKey] |
| DimProgramWeek[ProgramWeekKey] | FactAssessment[ProgramWeekKey] |
| DimDate[Date] | FactAttendance[ClassDate] |
| DimDate[Date] | FactParticipation[ClassDate] |

Do not relate `DimCohort` to `DimProgramWeek`: cohort filters facts through `DimLearner`, while week filters facts through `DimProgramWeek`. Connecting both dimensions would create ambiguous paths. Do not relate `AsOfWeek`. Do not relate `DataExceptions`. Do not relate `DimDate` to `DimProgramWeek`. Do not relate track to anything. Track filters through the learner.

Create a hierarchy on `DimLearner` named Learner: `CohortName`, then `Track`, then `LearnerName`.

## 4. Measures

Modeling, New table:

```
Measure = ROW ( "Measure", 1 )
```

Hide the `Measure` column. Then paste each block in `powerbi/measures.dax` as its own measure on that table.

Format rates as percentages, averages as numbers, `Is At Risk` as a whole number.

## 5. Pages

Filters, not edits. Sync `As Of Week` across Monday, Trends, and Learner. Do not sync it to Overview. Do not put the status filter on Monday.

### Monday

Slicers: `DimCohort[CohortName]`, `DimLearner[Track]`, `AsOfWeek[WeekLabel]`. Single select on the week. Default the week to Week 10 for the finished intake, and move it to Week 4 when you want the first Monday that was worth acting on.

Cards: `Monday Headline`, `Trainer Time`, `Cohort Anomaly`, `Files Agree`, `Hindsight`.

A table of `RuleBook`: Signal, Bar, Applies.

A table of learners, visual-level filter `Is At Risk` = 1:

- `LearnerName`
- `Track`
- `Call Reason`
- `Outcome (known only after the program)`
- `LearnerKey` (needed for drill-through; narrow the column)

At week 4 the table is empty and the headline says there are no calls. That is the result in `decisions/ADR-001-at-risk.md`, not a broken filter. At week 5, with no track filter, the one row is John Miller on Cloud. At week 6 the three rows are people who graduated.

Under the table, a second table of `DataExceptions`: `RawName`, `Reason`, `ClassDate`, `Track`. Empty on this intake.

### Overview

Slicers: cohort, track, and `DimLearner[GraduationStatus]`. No as-of week. These rates describe every week still in the files.

Cards: `Learners`, `Graduation Rate`, `Non-Graduation Rate`, `Certification Rate`, `Attendance Rate`, `Participation Rate`, `Lab Average`, `Quiz Average`.

A matrix or table with the Learner hierarchy on the rows, so it drills from intake to track to person. Values: the same rates. This page is where a board question gets answered.

A learner table: name, track, email, `Outcome (known only after the program)`, attendance rate, participation rate, lab average, quiz average. Include `LearnerKey` for drill-through.

Card: `Files Agree`.

### Trends

Same cohort, track, and as-of slicers as Monday.

Line chart, axis `DimProgramWeek[WeekLabel]`, four lines or a small-multiples set: `Week Attendance Rate`, `Week Participation Rate`, `Week Lab Average`, `Week Quiz Average`.

On that visual, filter `Week Is On Or Before As Of` to 1, so weeks after the selection disappear.

Card: `Cohort Anomaly`. At week 5 it should mention Cloud quizzes. At week 7 it should mention Power BI participation. At week 4 it should say nothing is that far behind.

### Learner

Drill-through page. Drill-through field: `DimLearner[LearnerKey]`. Also drop cohort and track on the page so the sentence stays in context, and the as-of slicer.

Cards: `LearnerName` (as a field), `Call This Week`, `Call Reason`, `Outcome (known only after the program)`.

A table with `WeekLabel` on the rows and the four week measures as values. Same visual filter, `Week Is On Or Before As Of` = 1. That is the week-by-week story, and the reason says which bars missed.

Turn on drill-through from the learner tables on Monday and Overview. Right-click a name, drill through, Learner.

## 6. What to check before you hand it over

Week 4, both tracks: headline is no calls. Hindsight says 0 on the list and 21 who did not graduate are not on the list.

Week 5: one call, John Miller, and the hindsight says 1 of that 1 did not graduate, 20 missed.

Week 10, Power BI only: attendance rate 100%. Cloud only: about 79%.

Files Agree, no filters: roster 140, live class 140 learners and 100 class days (50 per track, summed), participation the same, 0 unmatched, assessments 140, status 140, unreadable 0. The day counts add the two tracks together. Filter to one track and each day count is 50.

## 7. The two refresh tests

Remove `Module 7 Data\PowerBI Training\Zoom Attendance\Week 10` and the same folder under Cloud. Refresh. `AsOfWeek` no longer offers Week 10 from the live class. Put the folders back and refresh. The rows return. Lab week 10 stays while the folder is gone, because that column is still in the workbook. That is intentional: each feed keeps what it still contains.

To test a second intake, copy `Module 7 Data` to a sibling folder, for example `Spring 2025`, and refresh. You should get a second cohort, its own learners, and its own weeks. Delete the copy when you are done. Do not leave it in the folder you hand over unless you mean to.

A track folder named `Data Engineering Training`, with the same four role folders inside an intake, appears as Data Engineering on refresh. No new measure and no new relationship.
