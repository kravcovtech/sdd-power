# SDD Power

*[Русская версия](README.md)*

A Claude Code skill: discipline for long-running development against existing project documentation — with persistent state tracking and critical verification of the documentation itself.

It's for work that doesn't fit in a single session: the agent comes back to the project a week later with an empty context and has to understand within a minute what's done, what's left, and why a particular decision was made.

## Why this exists

The skill treats two diseases of long-running work with an agent.

**State is lost between sessions.** The context resets. A week later neither the agent nor the human remembers where they stopped or why that approach was chosen. The cure is four tracking files updated at the same moment as the code — not "later".

**Blind trust in the documentation.** Documentation is written by people; it goes stale and contains errors. An agent that executes faulty docs literally produces bugs that are hard to explain afterwards. The cure is a verification protocol with an objective criterion: an error is only what can be proven by a code fragment, two contradicting paragraphs, or a runtime failure. "I would do it differently" is not an error and goes into "Improvement proposals".

Both parts only work together with discipline. One "I'll write it up later" and the files can no longer be trusted, which makes them useless.

## How it works

State lives in `docs/sdd-power/`. The roles of the files don't overlap — that's the protection against the same thing sprawling across three places:

| File | Answers the question | Nature |
|---|---|---|
| `PLAN.md` | What is there to do? | Living document, rewritten |
| `WORKLOG.md` | What was done, and why? | Append-only, newest on top |
| `TIMELINE.md` | Where are we overall? | Table of stages |
| `LESSONS.md` | What have we been burned by? | Curated, hard budget |
| `stages/<ID>.md` | What does a closed stage amount to? | Written once, at closing |

By default the directory goes into `.gitignore`: this is the agent's working memory, not a repository artifact — it doesn't belong in PR diffs. The consequence is handled inside the skill: anything the team needs must reach the code, the documentation, or CLAUDE.md rather than staying only in the WORKLOG. The bridge between the decision journal and repository history is the short commit SHA recorded in every entry.

A few decisions that separate this from "keep a TODO file":

- **Coverage is checked in both directions.** Every task references a documentation section, and every documentation requirement is either covered by a task or explicitly moved to "Out of scope" with a reason. Otherwise a lost requirement surfaces at the very end.
- **The stage DoD is verified by commands**, not by a sum of checkboxes. A red run is a "fix and re-run" loop, not a verdict: a closed stage with a red DoD does not exist.
- **`[x]` only on observable confirmation.** "Should work" and "the change is trivial" don't count as evidence — otherwise the files start lying, and a lying file is worth nothing.
- **LESSONS.md holds rules, not a bug journal.** "Bug #14 closed 03-12" teaches nothing. "Don't buffer the full result before export — OOM on reports >10MB, use streaming" applies to new code. The budget is 20 rules and ~120 lines, because the file is read in full every session.
- **The strongest consolidation is turning a rule into a check.** What a test, a linter, or CI can catch shouldn't live as text betting on a future session's memory.
- **The documentation snapshot is dated.** Docs changed — re-sync the plan, don't work from memory.
- **Scope is held.** Duplication and dead code noticed along the way become tasks in PLAN.md, not part of the current diff. The exception is a finding that physically blocks the task.

## What it doesn't do

- This is a discipline, not an autopilot. The files are worth exactly as much as the honesty they're filled in with; an agent that marks `[x]` without verifying breaks the system faster than not having it.
- It doesn't replace documentation and won't write it for you. With no coherent source of requirements there's nothing to build a plan on.
- It doesn't settle architectural forks by itself. Questions whose answer changes the data model are escalated to the user before any code.
- It's overkill for a one-off small fix in a single session — no need to deploy the ceremony.
- The tracking won't survive a fresh clone and isn't visible to colleagues: it is deliberately outside git.

## Installation

The English version lives in `en/` and is installed by copying that directory:

```bash
git clone https://github.com/kravcovtech/sdd-power.git /tmp/sdd-power \
  && cp -r /tmp/sdd-power/en ~/.claude/skills/sdd-power
```

Windows (PowerShell):

```powershell
git clone https://github.com/kravcovtech/sdd-power.git $env:TEMP\sdd-power
Copy-Item -Recurse "$env:TEMP\sdd-power\en" "$env:USERPROFILE\.claude\skills\sdd-power"
```

For a single project, copy `en/` to `.claude/skills/sdd-power` inside the repository instead.

Restart Claude Code. The skill triggers on phrases like "start development from the docs" or "pick up where we stopped", and also whenever the project already has a `docs/sdd-power/` directory.

## Usage

**First session** — initialization:

> Start development from the documentation in `docs/`

The agent reads the documentation with a critical eye, creates `docs/sdd-power/`, decomposes the requirements into stages and tasks, shows the discrepancies and open questions it found — and waits for you to confirm the plan before the first line of code.

**Every session after** — continuation:

> Continue development

The agent reads the tracking files, reconciles them with the actual state of the code (the files can lie — work may have been done without it), deals with unclosed `[~]` items, and tells you in two sentences where you stopped and what comes next.

Useful phrases: "check against the plan", "record progress", "where did we leave off", "close the stage".

## Repository layout

```
.
├── README.md                             # Russian
├── README.en.md                          # English
├── LICENSE
├── SKILL.md                              # Russian skill (repository root)
├── assets/                               # Russian tracking templates
├── references/
│   └── docs-verification.md
└── en/                                   # self-contained English skill
    ├── SKILL.md
    ├── assets/
    │   ├── PLAN.template.md
    │   ├── WORKLOG.template.md
    │   ├── TIMELINE.template.md
    │   ├── LESSONS.template.md
    │   └── STAGE.template.md
    └── references/
        └── docs-verification.md
```

The Russian version sits at the root so that a plain `git clone` into `~/.claude/skills/` installs it directly; `en/` is a self-contained copy of the same skill.

`references/docs-verification.md` is loaded only when in doubt — the objectivity test, a catalog of error types with examples, borderline cases (the docs demand something insecure; the docs contradict working code; an error is found in an already implemented part), and the escalation format.

## Roadmap

- [ ] A command for a quick tracking audit against the code
- [ ] An example filled-in `docs/sdd-power/` on a demo project
- [ ] A variant with tracking inside git — for teams that need shared state

## Contributing

Did the system fall apart on your project, did the files drift from the code, or did the documentation-verification protocol produce a false positive? Open an issue with the concrete scenario or send a pull request. The most valuable cases are the ones where the discipline breaks in practice — that's where the rules come from. Keep the Russian and English versions in sync.

## License

[MIT](LICENSE) — free to use, including commercially. Attribution is appreciated but not required.

---

Maintained by [@kravcovtech](https://github.com/kravcovtech).
