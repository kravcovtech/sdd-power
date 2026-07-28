---
name: sdd-power
description: "Discipline for long-running development against existing project documentation, with persistent tracking (PLAN.md, WORKLOG.md, TIMELINE.md, LESSONS.md in docs/sdd-power/) and critical verification of the documentation itself. Use ALWAYS when the user says \"start development from the docs\", \"continue development\", \"where did we leave off\", \"what's done and what's left\", \"check against the plan\", \"update the plan and log\", \"record progress\", \"pick up where we stopped\", \"keep a development plan/timeline\"; mentions PLAN.md, WORKLOG.md, TIMELINE.md, LESSONS.md or the docs/sdd-power directory; complains that the project documentation contains errors or diverges from the code; or begins multi-step work that will span several sessions. Also trigger without any explicit mention of tracking if the project contains docs/sdd-power or PLAN.md and WORKLOG.md files (including at the root — a trace of an older version of the skill). Do NOT use for one-off small fixes that fit in a single session."
---

# SDD Power

A skill for long-running development against existing project documentation. It solves two problems:

1. **State is lost between sessions.** Context resets, and a week later nobody (you included) remembers what was done, what remains, and why a given decision was made. The cure is persistent tracking files kept in sync with the code.
2. **Blind trust in the documentation.** Documentation is written by people; it goes stale and contains errors. Executing faulty docs literally produces bugs that are hard to explain later. The cure is a verification protocol with objective criteria.

Both principles only work under discipline — "I'll write it up later" destroys the system within two sessions.

---

## Step 0: documentation, tracking, mode

**Where the project documentation lives.** If the user named a path, use it. Otherwise search in descending order of likelihood: `docs/`, `documentation/`, `spec/`, `specs/`, `*-docs/`, the README and nested `*.md` files at the root. Found one unambiguous candidate — work with it and tell the user. Found several or none — ask, don't guess: working from the wrong documentation is worse than one clarifying question.

**Where the tracking files live.** Always in `docs/sdd-power/` relative to the project root: `PLAN.md`, `WORKLOG.md`, `TIMELINE.md`, `LESSONS.md`. No directory — create it. Don't put them at the root: it's cluttered already, and a separate directory makes the tracking portable and lets one line exclude it from git.

**Git.** If the project is under git, make sure `docs/sdd-power/` is listed in `.gitignore`, and add the entry if it isn't:

```
# development working state (sdd-power), not for the repository
docs/sdd-power/
```

This is the agent's working memory, not a repository artifact: it does not belong in commit history or PR diffs. Keep the consequence in mind — these files won't survive a fresh clone and aren't visible to colleagues, so anything the team needs (decisions, constraints, documentation fixes) must reach the code, the documentation itself, or CLAUDE.md, rather than living only in the WORKLOG.

**CLAUDE.md.** On initialization, add one line there — so the files are found even in a session where the skill doesn't fire:

```
Development state lives in docs/sdd-power/ (PLAN, WORKLOG, TIMELINE, LESSONS, stages/). Read at the start of a session.
```

**Mode** is determined by the state of the project:

| What you see | Mode |
|---|---|
| `docs/sdd-power/` missing or empty | **Initialization** |
| Tracking files present | **Continuation** |
| Files present but contradicting the code | **Continuation**, starting with restoring accuracy |

---

## Initialization mode

1. **Read the documentation in full, with a critical eye.** Not a skim — you are building the entire plan on it. As you go, note contradictions, ambiguities, and places that diverge from the actual code.
   **Check what the docs are silent about.** Errors aren't the only defect: go through what the documentation doesn't say about things the implementation will need (error handling, extreme volumes, migration of existing data, access rights — whichever apply). An unnoticed gap surfaces mid-implementation, when changing approach is expensive; a noticed one is a line in "Open questions" or a deliberate assumption in the plan.
2. **Set up the infrastructure:** create `docs/sdd-power/` and `docs/sdd-power/stages/`, copy the PLAN, WORKLOG, TIMELINE, and LESSONS templates from `assets/` (the STAGE template is used later, when closing a stage), add the `.gitignore` entry and the CLAUDE.md line. Copy the templates rather than inventing the format again — a consistent format across projects saves time when you return to old code.
3. **Fill in PLAN.md**: stages and tasks with references to the documentation sections they are based on. The reference is mandatory — it makes a task re-checkable when the docs change.
   **Coverage in both directions:** walk the documentation and confirm that each of its requirements is either covered by a task or explicitly recorded in the plan's "Out of scope" section with a reason. Task references guarantee "every task is grounded in the docs", but not "the whole docs are decomposed into tasks" — a requirement lost at this step won't surface until the very end.
   **Stage DoD:** every stage gets a Definition of Done line: the observable state of the project after the stage closes, verifiable by commands. This is a criterion for the whole, and it does not reduce to the sum of task checkboxes.
   **Granularity:** one task ≈ one commit and one working session. A task that can't be finished in a session hangs in `[~]` for months, and the tracking stops reflecting reality — decompose those immediately.
4. **Fill in TIMELINE.md**: one row per stage from the plan, statuses still empty.
5. **Record the problems you found** in the PLAN.md sections "Documentation discrepancies" and "Open questions".
   Questions whose answer changes the architecture or the data model must not be left hanging in a table — settle them with the user before the plan is confirmed, one at a time, in descending order of impact. Before any code exists these answers are nearly free; afterwards each one costs a rewrite.
6. **Show the user the plan and the discrepancies you found, and wait for confirmation.** Do not start implementing before you get an answer: a misunderstood plan costs more than a minute of waiting. Present the plan decisions-first: start with what the user is most likely to want changed (data model, interfaces, user flows), and leave the mechanical parts for the end. For a task whose criterion is "I'll know it when I see it" (interface, copy, visuals), start with a cheap prototype to get a reaction, not a full implementation: fixing a prototype costs minutes, fixing an embedded implementation costs a task.

---

## Continuation mode

At the start of **every** session, before any code:

0. **Bring the infrastructure up to the current version of the skill.** The project may have been initialized by an earlier version, when parts of the system didn't exist yet. Check and silently repair whatever is missing (this step is idempotent — on an up-to-date project it does nothing):
   - the tracking files sit at the project root or somewhere else — move them into `docs/sdd-power/`;
   - no `docs/sdd-power/stages/` — create it;
   - no pointer line in CLAUDE.md — add it (without it the skill won't be picked up next session — this is the main anchor);
   - no `docs/sdd-power/` entry in `.gitignore` while git is in use — add it;
   - the files lack fields from the current templates (for example "Commit", "Verified", "Stage DoD") — don't rewrite old entries, just keep new ones to the current template.
   Repaired something — one WORKLOG entry about the migration, with the list.

1. Read PLAN.md, TIMELINE.md, and LESSONS.md in full, plus the top entries of WORKLOG.md. For closed stages read `stages/<ID>.md` rather than the worklog feed for those days — that's what the summary is for.
2. **Reconcile them with the actual state of the code.** The files can lie: work may have been done by hand, without you. Found a discrepancy — bring the files up to date first, note it in WORKLOG.md, and only then continue.
3. **Deal with unclosed `[~]` items.** The "in progress" status means the previous session was cut off mid-way: don't trust the status, check the code. Determine what is actually done, what is half-done, and what was never started, and bring the task to an honest state — finish it, roll it back, or re-split it. Unfinished work mistaken for finished is the most expensive kind of error in this system.
4. Tell the user in 1–3 sentences: where you stopped and what comes next.

**After context compaction or clearing** (`/compact`, `/clear`, a long session) re-read the tracking files before continuing. The tell that it's time: you don't remember the details of the current task or the most recent decisions. Re-reading is cheaper than doing the work twice or off-plan.

Read LESSONS.md always and in full — it exists precisely so that you don't repeat a mistake already analyzed.

---

## A critical stance toward the documentation

The documentation is the primary reference, but it is **not infallible**. You must distinguish real errors from your own preferences: without that line, "critical thinking" turns into unauthorized deviations that break the user's expectations.

An **error** is only what can be objectively demonstrated:

- an internal contradiction (two sections require incompatible things);
- a contradiction with the actual code, API, data schema, or dependency version;
- a technically infeasible or knowingly non-working solution;
- an obvious typo where the correct variant is unambiguously recoverable (a field, method, or endpoint name).

**Not an error:** "I would do it differently", "that's not how it's usually done", "there's a better way", "outdated approach, but it works". These are proposals. Follow the documentation and record the idea in PLAN.md → "Improvement proposals". The decision to change approach belongs to the user, not to you.

**Protocol when you find something** — three levels, by the cost of being wrong:

| Type | Action |
|---|---|
| Typo, fix is unambiguous | Fix it yourself → WORKLOG.md + "Discrepancies" in PLAN.md → continue |
| Affects architecture, system behavior, API contracts, or there are several possible fixes | Stop on that task, state the problem and the options, ask the user. While waiting, take independent tasks from the plan |
| Matter of taste | Follow the docs, record it in "Improvement proposals" |

Every confirmed discrepancy is a candidate for LESSONS.md: if the docs lie in that spot, you risk believing them again next session.

**Documentation snapshot.** The plan is built on a specific state of the docs — record the snapshot date/version in the PLAN.md header. Treat numbers and volumes from the docs as a snapshot on that date, not eternal truth. If the documentation changes (the user brings a new version, or the docs are being edited in parallel), don't keep going from memory: compare the changed sections against the plan, update the affected tasks and the snapshot in the header, and record the re-sync in the WORKLOG. Silently working from a stale plan is the same class of error as working from faulty docs.

**Fixes must reach the docs themselves.** A confirmed discrepancy that stays only in the PLAN table keeps lying to every subsequent reader of the documentation. If the docs live in the repository, offer the user a fix to the documentation itself (or make it, if they explicitly delegated that) and mark in the discrepancy table that the source has been corrected. The table is a log of findings, not the permanent home of the truth.

Borderline cases and examples — `references/docs-verification.md`. Read it when you're unsure whether you're looking at an error or a matter of taste.

---

## The tracking files and their roles

The roles don't overlap — that's the protection against duplicating the same thing in several places.

| File | Answers the question | Nature |
|---|---|---|
| **PLAN.md** | What is there to do? | Living document, rewritten |
| **WORKLOG.md** | What was done, and why? | Append-only, newest entries on top |
| **TIMELINE.md** | Where are we overall? | Table of stages, updated by status |
| **LESSONS.md** | What have we already been burned by? | Curated, distilled |
| **stages/<ID>.md** | What does a closed stage amount to? | Written once, when the stage closes |

Formats live in `assets/`. Don't invent your own.

### stages/: the closing summary of a stage

When a stage closes, create `docs/sdd-power/stages/<ID>-<short-name>.md` from the `STAGE.template.md` template. It is a **compression** of the WORKLOG entries for that stage's period, not a second retelling of the same work: the WORKLOG stays telegraphic, the expanded picture lives here. Once the summary is written, nobody goes back to the worklog feed for that period — "what's in stage 2 and how do I verify it" is answered by one 40-line file instead of ten chronological entries.

The "Worth knowing next" section is the place for local knowledge: pitfalls and conventions that matter to neighboring stages but don't rise to a project-wide rule. This keeps LESSONS.md light, since it has a hard budget: only project-wide applicable rules go there.

Stage closed — tag it in git as `stage/<ID>`: the state of the code at closing time is then one command away, without digging hashes out of WORKLOG entries.

### LESSONS.md: rules, not a bug journal

The key difference from the WORKLOG: what goes here is not events but **generalized rules applicable to future code**. The story "there was a bug, we fixed it" is already in the worklog and teaches you nothing.

Bad: `Bug #14: export crashed on large reports. Closed 03-12.`
Good: `Don't buffer the full query result before export — the process died with OOM on reports >10MB (WORKLOG 03-12). Use streaming.`

The second one can be applied; the first one can't.

**When to write.** Having closed a bug or resolved a discrepancy with the docs, ask yourself: could this mistake recur elsewhere in the project? Is there a generalizable rule? If yes — write it down. If no (a one-off typo, an accident) — the WORKLOG is enough.

**Budget: at most 20 rules and ~120 lines.** You read this file in full every session: a sprawling dump stops working, attention gets diluted, and the rules stop being followed. A productive day easily yields 15–20 rules, so the limit is reached quickly and that's normal.

**Hit the limit — consolidate first, then add.** In order: delete stale rules (code rewritten, docs fixed), noting in the WORKLOG why; merge rules about one class of error into one with several causes; move those that have become universal for the project into CLAUDE.md, where they're picked up automatically. A rule that can be neither generalized nor dropped displaces a weaker one — priority goes to whichever mistake is more expensive.

**The strongest form of consolidation is turning a rule into a check.** A rule whose violation is mechanically detectable shouldn't live as text: encode it as a test, a lint rule, or a CI check and delete it from LESSONS with a reference to that check. "Slot availability is `available_persons`, not `is_available`" relies as text on a future session's memory; as a test it catches the violation always and for free. Text is for judgment rules that a check can't express.

---

## Closing a stage

All tasks in the stage are `[x]` — don't move to the next one until the closing ritual is done. It takes a few minutes and makes the stage a unit you can come back to:

1. **Run the stage DoD** — the commands from its line in PLAN.md, in full, not from memory of individual tasks. Tasks may pass one by one while the stage as a whole doesn't. A red run is a loop, not a verdict: fix and re-run until green, and only the green result goes into the "How to verify" section of the summary. Can't get it fixed — the stage stays open and the problem is escalated to the user; a closed stage with a red DoD does not exist.
2. **Summary** `stages/<ID>-<short-name>.md` from the template — a compression of the worklog for the stage's period.
3. **Git tag** `stage/<ID>` on the current commit.
4. **TIMELINE.md** — status `completed`, date, link to the summary; update "Current position".
5. **PLAN.md** — check that the discrepancy, question, and finding tables aren't left in open statuses for closed tasks, and that the stage's confirmed documentation fixes have been offered for inclusion in the documentation itself.
6. **LESSONS.md** — the moment to consolidate: the stage produced new rules, some old ones went stale, and this is the best point to check the budget.

---

## Update rules

- **Update the files at the same moment as the code.** Finished a step → immediately an entry in WORKLOG.md, a checkbox in PLAN.md, a status in TIMELINE.md. Deferred updating is the main reason such systems die: one "I'll write it up later", and the files can no longer be trusted, which makes them useless.
- **Record the commit hash in the WORKLOG.** Made a commit — write its short SHA into the entry. The tracking files live outside git, and this hash is the only bridge between the decision journal and the repository history: it always lets you pull up the exact diff behind a "why we did it this way" entry.
- **Closed a task — walk the PLAN.md tables.** A task almost always closes something else too: a documentation discrepancy moves to "fixed", an open question to "resolved", a finding from "Noticed along the way" to done. This is the most common place things fall out of sync: a checkbox is easy to flip, while the tables below hang in "awaiting implementation" for weeks, and people stop believing them. Don't reuse or reorder row numbers in the tables — the WORKLOG and LESSONS reference them.
- **Reflect any change in every affected file, synchronously.** A new task, a cancellation, a change of approach, a confirmed documentation discrepancy — so that the files don't contradict each other. Record the reason in WORKLOG.md: a month later what matters is not only *what* changed but *why*.
- **Keep a WORKLOG entry within ~20 lines.** "Decisions and reasons" gets only the decisions that aren't obvious from the code and that a future reader would otherwise revert as accidental. Everything visible in the diff is already there — that's what the commit hash is for. Nobody finishes reading a fifty-line entry, and writing it takes time away from the work.
- **Don't defer the entry to the end of the session.** A session can be cut off at any moment — that's exactly the case this whole system is built for.

---

## The criterion for a finished step

A step counts as done only when all of the following hold:

1. **Functionality is confirmed by an observable result** — tests that ran, the output of a command that was executed, behavior that was checked. "Should work", "looks correct", "the change is trivial" are not evidence: an `[x]` without verification is precisely how the files start lying, and a lying file is worth nothing. Nothing to verify with at all — leave `[~]` marked "unverified" and tell the user.
2. The code matches the documentation — or a documented and justified deviation from it.
3. PLAN.md, WORKLOG.md, and TIMELINE.md are updated, and LESSONS.md has been extended if a generalizable lesson appeared.

At the end of each step, 1–2 sentences to the user: what was done and what's next in the plan. Keep it short — the details are in the files.

---

## Hold the scope

While working on a task you will notice unrelated things: duplication, dead code, missing tests, poor names. **Don't fix them along the way.** A sprawling diff can't be reviewed, it mixes the planned with the improvised, and it breaks the "one task — one commit" link.

Noticed something — file a task in PLAN.md and move on. The single exception: the finding physically blocks the current task; then fix it with the minimum necessary and record in the WORKLOG why you had to go beyond the scope.

---

## What not to do

- Don't start coding before reading the documentation and getting the plan confirmed.
- Don't deviate from the documentation without a proven error and a record of it.
- Don't mark a task done without observable confirmation.
- Don't duplicate the contents of the files in one another — each has its own role.
- Don't turn LESSONS.md into a bug journal.
- Don't ask for confirmation at every step: the user confirms the initial plan and architectural forks; the rest is your job.
- Don't deploy the whole ceremony for a one-off small fix — the skill isn't needed for that.
