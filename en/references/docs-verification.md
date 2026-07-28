# Critical verification of documentation: borderline cases

Read this file when you're unsure whether you're looking at a documentation error or your own preference. The cost of being wrong runs both ways: blind execution creates bugs, unauthorized deviations break the user's expectations and turn the docs into fiction.

## Contents

1. The objectivity test
2. Catalog of error types with examples
3. What is not an error
4. Borderline cases
5. How to phrase the evidence
6. How to escalate to the user

---

## 1. The objectivity test

Before calling something an error, check yourself with one question:

> Can I show the user concrete evidence — a code fragment, two contradicting paragraphs of the docs, a runtime error — after which they will agree the documentation is wrong, regardless of taste?

Answer "yes" → an error, apply the protocol.
Answer "no, I just think this way is better" → a proposal, follow the docs.
Answer "not sure" → treat it as an ambiguity: record it in "Open questions" and ask.

The phrase "that's bad practice" is not evidence in itself. Evidence is "this won't compile", "that method doesn't exist in version 3.2", "section 4 requires the opposite".

---

## 2. Catalog of error types with examples

### 2.1. Internal contradiction

Two places in the documentation require incompatible things.

Example: the "Data model" section declares `user_id` to be a string UUID; the "API" section describes the same parameter as an integer.

Action: this is not a detail — the schema depends on the choice. Stop the task, show both fragments, ask which one is correct.

### 2.2. Contradiction with the actual code or API

The documentation describes something that doesn't exist, or describes it differently from how it is.

Example: the docs prescribe calling `client.search(query, page_size=50)`; in the client code the parameter is named `limit` and `page_size` doesn't exist.

Action: if the correct variant is unambiguous — fix it in place, record it in "Discrepancies" and in LESSONS.md (the docs are unreliable in this area, you'll be back here). If it's unclear whether the docs or the code went stale — ask.

### 2.3. Technically infeasible solution

What is described cannot work in principle.

Examples: a synchronous call inside a context where only an async API is available; a field that doesn't exist in an external service's schema; an order of operations that uses a resource before it is created.

Action: almost always escalate — infeasibility usually means the author of the docs had a different architecture in mind, and guessing at it is dangerous.

### 2.4. Obvious typo

The correct variant is unambiguously recoverable.

Examples: `retrun` instead of `return`; the endpoint `/serach/` when everything else uses `/search/`; `HTTP 2000` instead of `200`.

Action: fix it yourself, record it in the WORKLOG. In LESSONS.md — only if typos in this document are systemic.

### 2.5. Stale information

The docs are correct for a previous version of a dependency, an API, or the project itself.

Example: a method is described that is marked deprecated in the current version of a library and removed in the installed one.

Action: if there is a directly documented successor — use it and record the discrepancy. If the migration changes behavior — escalate.

---

## 3. What is not an error

Everything below is material for the "Improvement proposals" section, not grounds for deviating:

- **A matter of taste.** "I'd use a dataclass instead of a dict" — follow the docs.
- **Style.** Naming, file structure, formatting, where the docs specify them explicitly.
- **Suboptimality without breakage.** A solution slower than possible, but working and within requirements. Optimizing without being asked is scope creep.
- **Incompleteness.** The docs are silent about an edge case. That's not an error but a gap: implement it sensibly, record the assumption in the WORKLOG, and if it matters, in "Open questions".
- **An outdated but working approach.** It works — don't touch it without the user's decision.
- **A conflict with your general knowledge.** A project is entitled to its own conventions; "the industry does it differently" is not an argument against an explicit requirement.

---

## 4. Borderline cases

**The docs require something insecure (a secret in the repository, certificate verification disabled, SQL concatenated with user input).**
Do not execute it silently. Security is the area where the cost of silence is incomparable to the cost of asking. Stop the task, explain the risk and the concrete threat, propose a secure variant, wait for a decision. If the user insists and it's their code — implement it, recording in the WORKLOG both the warning and their decision.

**The docs contradict existing working code.**
That fact alone doesn't settle who is right: the code may have outrun the docs, or it may have deviated from them by mistake. Check whether the code changed later. No clear answer — escalate, showing both sides.

**An error is found in an already implemented part.**
Don't rewrite retroactively on your own initiative. Record it in "Discrepancies", assess the impact on what's already done, and inform the user: rework may be needed, and that's their call.

**There are very many errors in the docs.**
Don't escalate each one separately — that paralyzes the work. Collect a batch of similar findings, present them at once, and propose a general rule (for example: "throughout section 3 field names are camelCase, in the API they're snake_case; I propose reading them all as snake_case"). An agreed rule goes straight into LESSONS.md.

**No confidence at all.**
The default is to follow the documentation and record the doubt in "Open questions". A silent deviation is worse than execution with a note.

---

## 5. How to phrase the evidence

In "Discrepancies" and when escalating, keep the structure: **what the docs say → what is actually the case → what confirms it → what you propose**.

Bad: `There's an error in the search documentation.`

Good:
```
"Search API" section, §3.2: the parameter is called `page_size`.
Actually: in `services/search_client.py:41` the signature is `search(query, limit=20)`,
there is no `page_size` parameter; a call per the docs will fail with TypeError.
Proposal: use `limit`, and patch the docs.
```

The second can be checked in ten seconds and decided on. The first requires an investigation.

---

## 6. How to escalate to the user

Escalation is not "I don't know, decide for me" but a prepared decision:

1. State the problem in one sentence.
2. Give the evidence in the structure from section 5.
3. Offer 2–3 concrete options with the consequences of each.
4. Name your recommendation and its basis.
5. Say what you'll work on while waiting (an independent task from the plan) — no need to idle.

Once you have the answer, record the decision in PLAN.md ("Discrepancies") and WORKLOG.md, and any generalizable rule in LESSONS.md. Otherwise you'll arrive at the same question again next session.
