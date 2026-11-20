# ADR-005: What survives the next intake and a third track

Status: accepted.

## Context

A second intake will be a new folder beside `Module 7 Data`, with the same track folders inside it. Next quarter a Data Engineering track is exported the way the trainers export today: either the Power BI layout or the Cloud layout. Abena will not pay for a rebuild. The grader will delete a later week, restore it, and add a second intake folder.

## Decision

These keep working with a refresh, and with the root parameter left on the parent of the intake folders.

- A new `Week N` folder of csv files, with the same six columns.
- A week folder removed and put back. Live-class days follow the files. The as-of list is the week numbers still present, not a typed list of 1 to 10.
- A second intake folder. Cohort key is the folder name. Learner key and week key include that folder, so week 1 of the new intake does not mix with week 1 of this one, and a repeated email does not become the same person.
- A new track folder named `Data Engineering Training`, or any other name ending in ` Training`, provided it contains the same role folders: `Zoom Attendance`, `Participation`, a labs folder whose name contains "lab", and a status folder whose name contains "status".
- Either duration format, either clock format, either sheet name, any file name.
- A status file that has not arrived yet. Those learners stay on the roster as in progress and stay out of the graduation rate.
- The call-list measure. It does not contain the number 140, the track names, or the final results of this intake. A learner who actually misses two bars will appear.

These will not keep working, and should not be patched around in silence.

- A duration written in a third way (for example seconds, or `1h 46m`). Those rows become exceptions and do not count as attended. The Monday agreement line shows the unreadable count.
- A participation file that is not one date and one comma-separated list of names.
- Lab or quiz sheets without an email column and `Week N` columns, or a status sheet without email and a graduation column.
- Role folders renamed so they no longer say zoom/attendance, participation, lab, or status.
- A third track stuffed into this intake folder but running a different set of weeks. Program week is per intake, shared by the tracks in that folder.
- Premium-only refresh (a dataflow, a deployment pipeline, a composite model). The file is import mode. Someone opens it, refreshes, and saves.

## Consequences

The build sheet tells the team to set `pIntakeRoot` once, to `C:\DataEngineering\dare-careers`, and then only to refresh. Adding Data Engineering does not require a new relationship, a new page, or a new measure. It requires the same four role folders.

The agreement line is what tells a non-technical user that the new folder was understood: learner counts by feed, class-day counts, unmatched names, unreadable values. A number other than zero on unmatched names means the participation rate is short, and the call list is not ready to book from.

## Alternatives rejected

- **A typed list of the two tracks.** Data Engineering would never appear.
- **A typed list of weeks 1 to 10.** A shorter or longer program would lie, and a deleted week 10 would still show as a choice.
- **One query per track, copied.** The second copy is the one that will not get the next fix.
- **Fuzzy matching, held in reserve for the new track.** It would attach a near-miss name to the wrong learner. The exception list is the reserve.
