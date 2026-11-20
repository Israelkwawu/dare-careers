# ADR-001: At risk means gone quiet, not predicted to leave

Status: accepted.

## Context

Abena can spend a trainer's afternoon on one learner, and she would rather have a short list of real calls than a long list of false ones. The files record, at the end, whether each learner graduated and whether that graduate was certified. They do not record a leaving date. Graduation is the only stand-in for "dropped out." Certification is a separate outcome: every certified learner graduated, and 27 graduates were not certified. The list she acts on during the program cannot look at either outcome, and it cannot look at later weeks.

The check that is available now is this finished intake. 21 of 140 learners did not graduate. Their attendance, participation, and marks up to any earlier week look like the 119 who finished. At week 4 the gap in recent participation is about two points, in the wrong direction.

## Decision

A learner is on the call list as of program week W when W is at least 3 and **at least two** of these are true for weeks W−1 and W (week 1 only, when W is 1, but the list does not start that early):

- In class for under 70% of class days. A day counts only when the session was more than 30 minutes.
- Took part on under 60% of class days.
- The average of that fortnight's lab average and quiz average is under 40.

Bars are strict. 70% participation is not a miss. A coursework average of 40 is not a miss. A session of 30 minutes is not attendance. A blank (none in this intake) does not count as a miss and does not enter the average. A score of 0 does both.

The first week to spend trainer time is **week 4**, the Monday after a full month. Week 3 is the first week the arithmetic is stable enough to show, and it is early enough to look back at. It is not early enough to book calls.

The list uses only weeks up through the selected week. Final status is shown beside it, labeled as known only after the program, and is not an input.

A group note, separate from the call list, fires when a track's week is more than 8 points worse than the average of its own earlier weeks, and only when at least three earlier weeks exist. Points are percentage points for attendance and participation, and marks for labs and quizzes. On this intake that note is: Cloud quizzes in week 5 (42.7 against 53.0), and Power BI participation in week 7 (77% against 86%). Cloud attendance in week 2 is a 9 point drop from week 1 alone, and it is not announced, because one week is a thin baseline.

## How this intake actually ended

Base rate: 21 of 140 did not graduate (15%).

| As of | On the list | Of those, did not graduate | False calls | Non-graduates missed |
| --- | ---: | ---: | ---: | ---: |
| Week 3 | 2 | 0 | 2 | 21 |
| Week 4 | 0 | 0 | 0 | 21 |
| Week 5 | 1 | 1 | 0 | 20 |
| Week 6 | 3 | 0 | 3 | 21 |
| Week 8 | 1 | 1 | 0 | 20 |
| Week 10 | 2 | 0 | 2 | 21 |

Week 4 is the week to act. The list is empty. All 21 who did not graduate are missed. That is the honest result, and an empty list is the right Monday answer. Lowering the bar to produce names would spend afternoons on people who were fine.

The names behind the other weeks, so the empty week 4 is not a trick of the cutoff:

- Week 3: Daniel Anderson and Isabella Clark, both Cloud, both graduated. Attendance 60% and coursework 27.5 and 33.8 over weeks 2–3. Participation did not miss the bar.
- Week 5: John Miller, Cloud, did not graduate. Over weeks 4–5 he was in class 60% of days, took part 70% of days (that bar did not fire), and his lab and quiz together averaged 36.8. One true call, and the other 20 who did not graduate still looked ordinary.
- Week 6: Christopher Baker (Cloud), Isabella Clark (Cloud), and Audrey Myers (Power BI). All three graduated. A name that appears in week 6 was not a person who left.
- Week 8 brings John Miller back. Weeks 9 and 10 name graduates only.

So the list flickers, and a single appearance is not evidence someone will leave. Across the program it does not recover the 21.

## Cost if this is wrong

If the bar is too high, Abena calls nobody and the 21 are missed. That is what this intake supports. The files do not contain an earlier pattern that would have found them without a large number of false calls.

If the bar is too low, she buys false alarms. The rejected coursework-only rule (fortnight average under 40, no second bar) at week 4 puts **35** learners on the list, **7** of whom did not graduate and **28** of whom did. Precision is 20%, against a 15% base rate. That is the long list she said she does not want. Twenty-eight afternoons, for seven hits, and fourteen of the twenty-one still missed.

## Alternatives rejected

- **Predict non-graduation from final status, or from later weeks.** That list could not have been built on the Monday it claims to describe.
- **A call for anyone under 50 on recent coursework.** Cohort labs and quizzes sit near 50 all program. The line would flag about half the room.
- **Attendance alone.** Power BI never misses the 30-minute line, so the bar never fires there. Cloud attendance at week 4 does not separate the seven who left from the thirty-three who stayed (about 76% against 78% over the trailing fortnight).
- **Participation alone.** At week 4 nobody, graduate or not, is under 60% over the trailing fortnight. The non-graduates were slightly more present, not less.
- **Always name the weakest ten.** That manufactures a quota of calls on a week when nobody has gone quiet.
- **Act at week 3.** Two calls, both graduates, none of the 21 found.
- **Treat the group dip as a person to call.** Week 7 Power BI participation and week 5 Cloud quizzes are a class problem. They go on the Monday note, not onto 100 individual call sheets.

## Consequences

Trainers are not booked from this list for the Aug 2024 intake. The Monday page still shows the three bars, the reason, and the hindsight counts, so a later intake that really does go quiet will produce a short list without a rebuild. Until a learner misses two bars in the same fortnight, the sentence on the page is that there is no call.
