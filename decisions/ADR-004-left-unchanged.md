# ADR-004: What was left as it arrived

Status: accepted.

## Context

The folders contain real traps, listed in `data_findings.md` and handled in ADR-003. They also contain things that look like traps and are not. Fixing those would change a rate that is currently telling the truth.

## Decision

Leave these as they are. Do not patch them in the query.

- **Power BI attendance, all 5,000 sessions between 90 and 120 minutes.** Each row has its own join and leave, and the duration equals that span. The 30-minute rule is applied and removes nobody. The call list does not invent absences to make the track look more like Cloud.
- **Scores of 0.** They are inside the 0–100 scale, the cells are not blank, and both tracks have them. They stay in the average and they can trip the coursework bar.
- **The status words `Graduate`, `Non Graduate`, `Certified`, `Not Certified`.** Same spelling on every row. Rates match those strings. A display label can say "did not graduate" without rewriting the stored value.
- **`30-Sep-2024` in Week 9.** That Monday is the first day of the week that ends 4 October. The file is in the right folder.
- **The file names `Labs & Quizes.xlsx` and `Status of Participanat.xlsx`.** They stay on disk. The queries never call them by those names.
- **Shared minute-level join times.** A few learners on a day share a start minute. That is not a duplicated row: the emails differ, and most timestamps are unique.
- **Emails at `example.com` and `msc.com`.** They are the trainers' addresses, they are unique, and they join cleanly. The domain is not cleaned and not used as the track. Track comes from the folder, so a later track can use either domain.

## Consequences

Power BI attendance cannot, on this evidence, put a learner on the call list by itself. That is a property of the intake, and the Monday page has to be useful anyway: participation, labs, quizzes, and the group note still move. Cloud keeps a real attendance signal, including the 19 sessions of exactly 30 minutes counted as absent.

Anyone who "repairs" Power BI duration, or drops zeros, is changing history. The findings file says what was compared so a later reader can see the check rather than reopening it.

## Alternatives rejected

- **Replace Power BI duration with a guessed absence pattern.** Nothing in the file supports a guess, and join/leave confirms the recorded minutes.
- **Map `Non Graduate` to a new status value in the model only.** Unnecessary for the count, and it hides the words the export actually uses. The overview can format the label in the measure.
- **Move `30-Sep-2024` into Week 8 or Week 10 by the calendar month.** The trainers' week folder is the program week. The month boundary is not.
