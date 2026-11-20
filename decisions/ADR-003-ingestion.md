# ADR-003: Read the folders, both duration formats, and trimmed names

Status: accepted.

## Context

The folder tree is the interface. The next week's files arrive in the same folders. The next intake arrives as a sibling of `Module 7 Data`. Nobody on Abena's team edits a query. The two trainers already disagree on file names, sheet names, and how duration is written. A third track next quarter will be exported the way one of them exports today.

The parameter `pIntakeRoot` points at the folder that **contains** the intake folders. For this drop that is `C:\DataEngineering\dare-careers`, not `Module 7 Data`. Pointing it at the intake itself still loads this intake, and it will miss a sibling intake until the parameter is moved up.

A file is in scope when it sits under a folder whose role is live class, participation, labs, or status. Notes beside the data are ignored. `~$` lock files are ignored.

## Decision

**Identity.** Email is trimmed and lower-cased. The learner key is the intake folder plus that email. The display name is the Zoom name. Names were stable: one name per email. The track name is the track folder with the suffix ` Training` removed, and `PowerBI` is shown as `Power BI`. Any other name, including `Data Engineering`, passes through.

**Cohort.** The key is the intake folder name. The label is the month and year of the first class date, plus the word intake. Two folders that start in the same month keep the folder name on the label so they do not merge.

**Live class.** Week number is the number in the `Week N` folder, not a date calculation. The class date is the file name (`05-Aug-2024`). If two rows share a learner and a date, minutes are summed first and the 30-minute test runs on the total, so a rejoin is one session. This intake has no rejoins. A role other than blank or Participant is not a learner. This intake is all Participant.

**Duration.** If the text contains a colon, `h:mm:ss` becomes hours × 60 + minutes + seconds / 60, and `m:ss` becomes minutes + seconds / 60. Otherwise the value is already minutes. Attended means the minutes are **greater than 30**. Join and leave are not used to rebuild duration. On every row in this intake they already match, and the clocks are not in one format (`06:02 PM` against `18:09`).

**Participation.** Split the cell on commas, trim, drop empties, lower-case, collapse internal spaces. Match to the Zoom name in the same intake and track. One match credits that learner. Two matches credit nobody and land on the exception list. No match lands on the exception list. No fuzzy match. A day the learner is not listed is `Participated` = 0. This intake matches 6,037 participations and produces no exceptions.

**Assessments.** Sheets that have an email column and at least one `Week N` column are unpivoted. A sheet name containing "quiz" is `Quiz`; containing "lab" is `Lab`. A blank cell is a blank score. Zero stays zero. A non-numeric token becomes an exception and a blank score, not a zero.

**Status.** The sheet that has email and a graduation column supplies the two status fields. A learner with no status row stays on the roster with blank status and is left out of graduation and certification rates. They still count in attendance and in the call list.

**Who is on the roster.** The union of emails from the live class, the assessments, and the status file. A participation name with no email does not create a learner.

## Consequences

Refresh picks up a new `Week N` folder, a new file in a known role folder, and a new intake folder beside this one, with no edit other than the root parameter the first time. File names can change. Sheet names can change. Column names cannot: email, the week headers, Date, Participants, Graduation Status, Certification Status, and the six live-class headers are the contract.

Leading spaces are removed, so the planted padding on the participation list does not create false absences. The exactly-30 sessions stay absent.

## Alternatives rejected

- **Hard-coding `Labs & Quizes.xlsx` or `Status of Participanat.xlsx`.** The other track uses different names. The next trainer will too.
- **Recomputing minutes from join and leave.** A third clock format would change attendance even when the duration column is the field the 30-minute rule refers to. Duration is that field.
- **Fuzzy name matching.** This intake does not need it. A near miss on the next intake should show up as an unmatched name, not attach to the wrong learner and hide a real absence.
- **Typing the cohort as "Autumn 2024" in a query.** The folder and the first class date already say what it is, and a typed label will not appear for the next folder.
- **An inner join of every feed to the live-class days.** Removing a week folder would also hide participation and labs that are still in the workbooks. Each feed keeps the rows it actually contains.
