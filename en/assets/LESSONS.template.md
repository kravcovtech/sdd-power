# LESSONS — <project name>

Rules extracted from mistakes already made and from confirmed discrepancies with the documentation.
**Read in full at the start of every session. Budget: at most 20 rules and ~120 lines.**
Hit the limit — consolidate first (delete stale ones, merge similar ones,
move universal ones to CLAUDE.md), then add.

The rules in this file take precedence over the documentation: they are based on behavior that was actually verified.

## What belongs here

A generalizable rule of the form "don't do X, because Y" — something applicable to new code.
This is NOT a bug journal: the story "there was a bug, we fixed it" lives in WORKLOG.md and teaches nothing.

Bad: `Bug #14: export of large reports crashed. Closed 03-12.`
Good: `Don't buffer the full result before export — OOM on reports >10MB (WORKLOG 03-12). Use streaming.`

## File hygiene

- A one-off accident or typo isn't a lesson; the WORKLOG is enough.
- Several rules about one class of error — merge them into one with several causes.
- A stale rule (code rewritten, docs fixed) — delete it, noting the reason in the WORKLOG.
- Close rules — merge them.
- A rule that has become universal for the project — move it to CLAUDE.md: from there it's picked up automatically.
- A mechanically verifiable rule — encode it as a test/lint rule/CI check and delete it from here with a reference to that check. A check catches the violation always; text catches it only while someone remembers it.

---

## <area: e.g. data export>

- **Rule:** <what to do or not to do>
  **Reason:** <what happened, reference to the WORKLOG or discrepancy #>

## <area: documentation>

- **Rule:** <e.g. the `page_size` field in the docs is called `limit` in the real API>
  **Reason:** <the docs diverge from the code, Discrepancy #2>

## <area: testing / build / dependencies>

- **Rule:** ...
  **Reason:** ...
