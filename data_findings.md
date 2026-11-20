# Data findings: Autumn 2024 intake

Checked against the folders as shipped. 140 learners, 50 class days, two tracks. The sets match. A few small defects would change who gets a call if a refresh stepped over them. Several things that look broken were checked and left alone.

## What would change a call

Ranked by danger to the Monday decision.

1. **The people who did not graduate never went quiet.** This is the result that matters, and it is not a broken cell. 21 learners did not graduate (14 Power BI, 7 Cloud). Through week 10 they still attended, still took part, and still scored like the people who finished. At the end of week 4, recent participation was about 89% for them and 87% for graduates. There is no leaving date in the files, so a call list cannot be checked against the week someone left. It can only be checked against who finished. Any list that claims to spot dropouts early, on these files, is stronger than the evidence. Detail and the week-by-week test are in `decisions/ADR-001-at-risk.md`.

2. **Duration is stored in two formats.** Power BI sessions are `h:mm:ss` (for example `1:46:00`). Cloud sessions are whole minutes (for example `66`). Join time and leave time agree with that duration on every row, in both tracks, so the column is real once both formats are read. Treating both as a clock, or both as a plain number, wipes attendance for one track. Cloud is the only track where attendance varies, so a bad parse removes the only attendance signal the list has.

3. **Exactly 30 minutes is not attended.** The rule is more than 30 minutes. Cloud has 2,000 sessions: 1,585 are over 30 minutes, 396 are under 30, and 19 are exactly 30. Those 19 are absences. Counting "30 or more" as attended marks 19 missed sessions as present. Power BI has 5,000 sessions, all between 90 and 120 minutes, so the rule removes nobody on that track.

4. **Participation names carry a leading space.** Each day is one cell, `First Last, First Last`. Every name after the first has a space in front of it. Trim, then match the lower-case name to the Zoom name inside the same intake and track. Without the trim, almost every name fails, almost everyone looks absent, and the call list fills up. After the trim, every name on every day matches exactly one Zoom name. There is no trailing comma, no blank token, and no name shared by two learners.

5. **The two tracks were not exported by the same person.** The queries have to follow the folder and the columns, not the file name.

| Role | Power BI | Cloud |
| --- | --- | --- |
| Live class | `Zoom Attendance/Week N/<dd-Mon-yyyy>.csv` | Same folders and file names |
| Participation | `Participation records.xlsx`, sheet `Sheet1` | `participation.xlsx`, sheet `Participation` |
| Labs and quizzes | `Labs & Quizes.xlsx`, sheets `Labs` and `Quizzes` | `labs_and_quizzes.xlsx`, same sheet names |
| Status | `Status of Participanat.xlsx` | `participant_status.xlsx` |

Both tracks use the folder name `Labs & Quizes`. A query aimed at one trainer's file name drops the other track on refresh. Clock text also differs (`06:02 PM` against `18:09`). Duration is read from the duration column, not recomputed from the clock, because the two clocks are not the same shape and the duration already matches the span.

## Reconciliation

Every learner is in exactly one track. Emails were compared after trimming and lower-casing. The same 140 addresses are in the live class, the labs, the quizzes, and the status file. Nobody is in both tracks. No blank email, no duplicate email on a class day, no second name on an email, no hidden sheet, no extra file, no header that differs from `Name, Email, Join Time, Leave Time, Duration, Role`.

| | Power BI | Cloud | Together |
| --- | ---: | ---: | ---: |
| Learners | 100 | 40 | 140 |
| Graduated | 86 | 33 | 119 |
| Did not graduate | 14 | 7 | 21 |
| Certified | 68 | 24 | 92 |
| Graduated, not certified | 18 | 9 | 27 |
| Live-class rows | 5,000 | 2,000 | 7,000 |
| Sessions over 30 minutes | 5,000 | 1,585 | 6,585 |
| Sessions of exactly 30 minutes | 0 | 19 | 19 |
| Days taking part | 4,253 | 1,784 | 6,037 |
| Average lab | 49.8 | 50.9 | |
| Average quiz | 51.0 | 52.8 | |

Certification is only present for graduates. All 21 who did not graduate are `Not Certified`. Status text is only `Graduate`, `Non Graduate`, `Certified`, and `Not Certified`, spelled the same way on both tracks.

Class days are the same 50 dates on both tracks, and the same 50 dates in the participation workbooks. No weekend, no gap, no date filed under the wrong week. Week 1 starts Monday 5 August 2024. Each week folder holds the five weekdays. Week 9 is Monday 30 September through Friday 4 October, which is why `30-Sep-2024` sits in that folder. Week 10 ends Friday 11 October 2024. 50 files per track, 100 files in all, 5 per week.

The 21 who did not graduate, all of them `Not Certified`:

- Cloud: Anthony Mitchell, Emily Davis, John Miller, Matthew Nelson, Natalie Collins, William Harris, Zoe Walker.
- Power BI: Abigail Brooks, Ava Mitchell, Bella Morales, Charles Coleman, Charlotte Hill, Eleanor Barnes, Ethan Kelly, Liam Brown, Lucy Nguyen, Michael Scott, Olivia Martin, Owen Cox, Samantha Chavez, William Cooper.

The other 119 learners graduated. 92 of those 119 were also certified.

## Checked, and left alone

- **Power BI attendance is complete, and the times are real.** Every session has its own join and leave, and the duration equals that span. It is not one meeting length copied onto every row. It is a weak signal for a call list, not a column to repair. Two learners sometimes share a minute. With minute-level times and a hundred people, that is ordinary.
- **A score of 0 is a score.** Labs and quizzes have no blanks and nothing outside 0 to 100. Power BI has 13 lab zeros and 11 quiz zeros. Cloud has 4 lab zeros and 2 quiz zeros. Turning zeros into blanks would lift averages and hide a failed week.
- **`Non Graduate` is the status text,** with a space, on every row that uses it. It does not need a cleaned synonym to be counted.
- **File-name typos stay in the folders.** `Quizes` and `Participanat` are how the files arrive. Renaming them would break the next drop. The queries do not look for those names.
- **Cohort is not a column.** Which intake a row belongs to is the folder it arrived in. For this drop that folder is `Module 7 Data`, shown as the Aug 2024 intake because the first class day is 5 August 2024.

## What the group did, by week

Worth knowing on a Monday. Not a defect.

- Power BI participation in week 7 was 77%, against 86% across the earlier weeks. Attendance that week was still 100%.
- Cloud quizzes in week 5 averaged 42.7, against 53.0 across the earlier weeks.
- Cloud attendance in week 2 was 78%, against 86% in week 1. One prior week is too thin to call the group off course, so the Monday note waits until a week has three earlier weeks behind it. From week 4 on, the only group notes on this intake are the Power BI week 7 participation dip and the Cloud week 5 quiz.

Marks sit near 50 in both tracks for the whole program. A single weak quiz is normal. That is why a coursework bar of 40, and only when a second bar is missed in the same fortnight, is the line in `decisions/ADR-001-at-risk.md`.
