# WORKLOG — <project name>

A journal of completed work. **Append-only: new entries go ON TOP, old ones are neither edited nor deleted.**
If an entry turns out to be wrong — don't fix it, add a new one with an explanation.

This file lives outside git, so the "Commit" field is mandatory: the short SHA is the only bridge between this journal and the repository history.

**Entry budget — about 20 lines.** "Decisions and reasons" gets only the decisions that aren't obvious from the code. What's visible in the diff is already there.

---

## [YYYY-MM-DD HH:MM] — <short step title>

- **What was done:** <to the point, without retelling the code>
- **Commit:** `<short SHA>` (or "not committed")
- **Verified:** <what confirms it works: test run, command output, manual check>
- **Decisions and reasons:** <what you chose and why exactly that; the "why" is what's valuable here, the code shows the "what">
- **Facts and measurements:** <optional: numbers that will later ground decisions>
- **Deviations from the plan or documentation:** <what and the justification> → <how PLAN.md was updated>
- **Closed in PLAN.md:** <which discrepancies / open questions / findings moved to a closed status; otherwise "none">
- **Lesson for LESSONS.md:** <the rule, if the mistake generalizes; otherwise "none">

---

<!-- Example of a filled-in entry — delete when starting a project:

## [2026-03-12 14:30] — CSV report export

- **What was done:** implemented the `/export/csv` endpoint with a streamed result.
- **Commit:** `a3f19c2`
- **Verified:** `pytest tests/test_export.py` — 12 passed; a 40MB report exported, memory stayed within 90MB.
- **Decisions and reasons:** streaming instead of buffering — on reports >10MB the process died with OOM when loading fully into memory.
- **Deviations from the plan or documentation:** the docs describe a `page_size` parameter, in the real API it's called `limit` → recorded in "Discrepancies" #2, fixed in place.
- **Lesson for LESSONS.md:** yes — don't buffer the full result before export.

-->
