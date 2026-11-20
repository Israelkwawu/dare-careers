# ADR-002: One star schema, week scoped by the intake, as-of kept off to the side

Status: accepted.

## Context

The report has to slice by intake, track, and week without double-counting, and the call list for a selected week may use only rows up through that week. A second intake will land as a sibling folder. Track is not a fact of its own: a learner sits in one track for the whole program. Power BI Desktop, import mode, no Premium features.

## Decision

Loaded tables:

- `DimCohort` — one row per intake folder. Key is the folder name (`Module 7 Data`). Display name comes from the first class date (`Aug 2024 intake`). Start and end dates are the first and last class dates in the folder.
- `DimLearner` — one row per learner per intake. Key is intake folder plus email. Carries track, display name, email, and the two final statuses (blank when the status file has not arrived). Cohort name is copied onto the learner so the drill hierarchy Cohort, Track, Learner sits on one table. The relationship to `DimCohort` is still the filter path.
- `DimProgramWeek` — one row per intake per program week. Key is intake folder plus week number. Week number on a live-class file comes from the `Week N` folder. A participation date takes the week of the live-class file with that date. If that file has been removed, the week is counted from the Monday on or before the intake's first remaining class date, seven days at a time. Assessment weeks come from the `Week N` column headers. Tracks in the same intake share these weeks.
- `DimDate` — one row per calendar day from the first class date to the last. Related only to the daily facts. Not related to `DimProgramWeek`.
- `AsOfWeek` — week numbers that exist in `DimProgramWeek`. No relationship. Measures read the selected number and apply it themselves. If nothing is selected, they use the latest week still in the files.
- `FactAttendance` — one row per learner per live-class day in their intake and track. `Attended` is 1 when the summed minutes that day are over 30, else 0. A learner missing from that day's file is 0, not a deleted row, so the rate has a denominator.
- `FactParticipation` — one row per learner per participation date. `Participated` is 1 or 0.
- `FactAssessment` — one row per learner per week per type (`Lab` or `Quiz`). `Score` is blank when the cell was blank, and 0 when the cell was 0.
- `DataExceptions` — unmatched or ambiguous participation names, unreadable durations, unreadable scores, unreadable dates. Not related. Measures apply the intake and track filters with `TREATAS`.
- `FeedCheck` — learner counts and day counts by feed, intake, and track, taken from the files before the learner-day grid is built. This stops the grid from pretending a missing feed still covered everyone.
- `RuleBook` — the three bars and the call rule, in words, for the Monday page.

Relationships are one-to-many, single direction, from the dimension to the facts:

- `DimCohort[CohortKey]` to `DimLearner` and to `DimProgramWeek`.
- `DimLearner[LearnerKey]` to all three facts.
- `DimProgramWeek[ProgramWeekKey]` to all three facts.
- `DimDate[Date]` to `FactAttendance[ClassDate]` and `FactParticipation[ClassDate]`.
- `DimCohort[CohortKey]` to `FeedCheck[CohortKey]`.

Track is not a dimension and is not a key on the facts. Filtering `DimLearner[Track]` reaches the facts through the learner. That avoids a second path from track to week.

`WeekNumber` is hidden on the facts so it is not used to build a second week relationship. The visible week is `DimProgramWeek`.

As-of measures clear filters on `DimProgramWeek` and put back `WeekNumber <= selected week` (or `=` for a single week on a trend). They do not clear `DimLearner`. A cohort slicer still limits the facts through the learners. Trailing measures use weeks W−1 and W. Overview rates do not apply the as-of week: they describe whatever weeks are in the files after a refresh. The Monday page, the trends page, and the learner page are the pages that follow the selected week.

Final status is a column on the learner, used by the overview rates and by the hindsight sentence. No measure that decides `Is At Risk` reads it.

## Consequences

Two intakes with the same week number do not collapse, because the week key includes the folder. The same email in a later intake does not collapse, because the learner key includes the folder. Removing a `Week N` folder removes those live-class days on refresh. Lab columns that are still in the workbook remain, which is what the file still says. Deleting a week properly means the column is gone as well as the folder.

A track that ran a different calendar inside the same intake folder would inherit that folder's week numbers. The program as run does not do that. A new intake in its own folder gets its own weeks.

## Alternatives rejected

- **One week dimension of 1 to 10, typed in.** A removed week 10 would still appear, and two intakes would share weeks that are not the same dates.
- **An active relationship from the date table to the program week.** Filtering a date and a week together would fan out. The date table serves the daily facts only.
- **Track as its own dimension related to both learners and weeks.** Two filter paths into the facts, and easy to double-count.
- **Putting the as-of week on `DimProgramWeek` as a page filter.** That shows one week. It does not show "everything known up through this week," and it cannot show a fortnight that starts in the previous week. A disconnected table lets each measure choose cumulative, trailing, or this week.
- **Calculating the call list in Power Query for the latest week only.** The Monday view has to move back through the finished intake. The flag is a measure so the selected week changes it.
