# PLAN — <project name>

Requirements source: `<path to documentation>` — snapshot of <date/version>
Last updated: <date time>

Numbers and volumes from the documentation reflect the snapshot date. Docs changed → re-sync the plan and set a new snapshot date (entry in the WORKLOG).

Statuses: `[ ]` not started · `[~]` in progress · `[x]` done and verified · `[!]` blocked

`[x]` is set only on observable confirmation that it works. Not verified — stays `[~]` with a note.
Task size: roughly one commit and one working session. Doesn't fit — decompose it.

---

## Stage 1. <stage name>
<!-- closed: see stages/1-<name>.md, tag stage/1 -->
**Stage DoD:** <observable state after closing + the commands that verify it as a whole>

- [ ] **<task>**
  - Result: <what must work once it's finished>
  - Basis: <documentation section>
  - Verification: <what will confirm it: which test, which command, which behavior>
- [ ] **<task>**
  - Result: ...
  - Basis: ...
  - Verification: ...

## Stage 2. <stage name>
**Stage DoD:** <...>

- [ ] **<task>**
  - Result: ...
  - Basis: ...
  - Verification: ...

---

## Open questions

Ambiguities in the documentation that require a decision from the user. A task depending on an open question is marked `[!]`.

| # | Question | Blocks | Status |
|---|---|---|---|
| 1 | <what is ambiguous> | <task> | awaiting answer / resolved |

---

## Documentation discrepancies

Proven errors in the documentation. Each one is a candidate for LESSONS.md.

| # | Where | What's wrong (evidence) | Resolution | Status |
|---|---|---|---|---|
| 1 | <docs section> | <why this is objectively an error> | <what we did or propose> | awaiting decision |

Statuses only from this set: `awaiting decision` · `awaiting implementation` · `fixed` · `accounted for` · `out of scope`.
`fixed`/`accounted for` in the code ≠ fixed in the docs: if the docs live in the repository, note separately whether the source itself was patched.
Closed a task — check whether it closes a row in this table.
In every plan table, don't reuse or reorder the numbers — the WORKLOG and LESSONS reference them.

---

## Noticed along the way

Problems spotted while doing other tasks: duplication, dead code, gaps in tests. Not fixed on the spot — they land here and get planned separately.

| # | What was noticed | Where | Priority |
|---|---|---|---|
| 1 | <finding> | `path/file.py` | low / medium / high |

---

## Out of scope

Documentation requirements deliberately left out of the plan. This section closes the coverage check: every requirement in the docs is either in the tasks or here.

| # | Requirement (docs section) | Why out of scope | Whose decision |
|---|---|---|---|
| 1 | <section> | <reason> | user / default (reversible) |

---

## Improvement proposals

"I'd do it differently" ideas — not documentation errors. Implemented only by the user's decision.

| # | Proposal | Why | Status |
|---|---|---|---|
| 1 | <what is proposed> | <benefit> | proposed / accepted / rejected |
