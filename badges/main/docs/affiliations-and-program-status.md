# How affiliations and organization status work

The Portal shows several figures about an organization that are easy to mix up:
**Affiliated since**, **Facilitators since**, the org's **status chip** (Active /
Formerly active / …), and the per-training **program status** chips (New / Ongoing /
Reinstated). They come from the same place — the people linked to the org — but they
answer different questions.

This doc explains what each one means, what creates them, and what changes them.

---

## The big idea

An **affiliation** is a link between one person and one organization. It has a
**title**, a **start date**, and an **end date**.

There are two kinds, and they are not interchangeable:

| Kind | Title | What it says | Dates |
|---|---|---|---|
| **Job affiliation** | Anything else — "Counselor", "Program Director", even "Lead Facilitator" | Who this person *is* to the org | Usually none — we rarely know when they took the job |
| **Facilitator affiliation** | Exactly **"Facilitator"** | This org was **running an art program**, staffed by this person, over this period | Dated to the training that conferred it |

**Only facilitator affiliations decide anything about the organization's program.** A
job affiliation never makes an org active and is never touched by reconciliation. One
person usually has both at the same org — a "Lead Facilitator" job affiliation *and* a
plain "Facilitator" one.

> The title must be **exactly** "Facilitator". "Lead Facilitator" and "facilitator"
> are job titles, not facilitator affiliations. If an org looks wrong, this is the
> first thing to check.

Everything else in this doc is the Portal answering **two separate questions** off
those facilitator affiliations:

1. **Is this organization running a program now?** → the status chip.
2. **What was this organization at this training?** → the program status chip.

They can legitimately disagree. An org can read **Ongoing** at a training in 2022 and
**Formerly active** today — that's not a bug, it's two questions about two moments.

---

## Where facilitator affiliations come from

- **Registering someone for a facilitator training** and linking them to an
  organization creates their facilitator affiliation, **dated to the training's start
  date** — not to the day they registered.
- **Registering for anything that isn't a facilitator training** creates the job
  affiliation only. Attending an event does not make anyone a facilitator.
- **By hand** — you can add, edit, and end affiliations on the person's edit page, the
  organization's edit page, or the affiliation's own edit page.
- **Reconcile affiliations** (after the training) trues them up against who actually
  turned up. See below.

---

## Question 1 — Is this organization running a program now?

The status chip on the org index, profile, and edit page. Checked in this order:

| Chip | Means |
|---|---|
| **Active** | Someone's facilitator affiliation is current |
| **Upcoming** | A facilitator is scheduled (future start date) but none is current yet |
| **Formerly active** | There were facilitators, but every one of them has ended |
| **Never active** | No facilitator affiliation at all |

- **Upcoming is admin-only.** Non-admins see a not-yet-started program as plain
  "Inactive", coloured like Never active — the public view reflects today, not a
  scheduled future.
- **The filter has one more option than the chip.** The org index and people directory
  offer **Active / Inactive / Upcoming / Formerly active / Never active**. "Inactive"
  is the umbrella: everything that isn't currently active, including Upcoming.
- **On the edit page the chip updates live** as you type dates into the affiliation
  rows, so you can see what a change will do before saving.

**The old stored "Organization status" field is not used for any of this.** It is
legacy data that drifted. It survives only to raise the mismatch warning on the edit
page when it contradicts the affiliations — expect that warning on a fair number of
orgs.

---

## Question 2 — What was this organization at this training?

The program status chip, judged **as of one date** — normally the training's start
date:

| Chip | Means |
|---|---|
| **New** | No facilitator affiliation started **before** that date |
| **Ongoing** | An earlier facilitator affiliation was **still running** on that date |
| **Reinstated** | There were earlier facilitator affiliations, but all had **ended** before that date — a lapse, now returning |

Two things follow from "before":

- **A first-time org reads New at its own training.** The affiliation that training
  creates starts *on* the training date, which isn't "before" it.
- **Revisiting an old event always reports what was true then.** These figures back
  grant applications, so the same question about the same past date must give the same
  answer forever.

**Where there's no event in view** — the cross-event attendees index and its charts —
the status reads **as of January 1 of the current year** ("where each program stands
this reporting year"). Those pages say so.

Every chip has a **hover explanation**: the date it was judged on, when the program
went (or last was) active, and the full facilitator history.

---

## "Affiliated since" vs "Facilitators since"

| Figure | Counts | Shown as | Where |
|---|---|---|---|
| **Affiliated since** | **All** affiliations, any title | Merged year periods, e.g. `2010-2012, 2026`; falls back to the org's own start date | Org profile, org edit page |
| **Facilitators since** | **Facilitator** affiliations only | Merged **month** periods, e.g. `Aug 2015 – Jun 2018, Feb 2024`; blank if the org never facilitated | Org index column, org profile, org edit page |

Both merge overlapping periods and show a real gap as a gap — a lapse and return reads
as two periods, not one unbroken range.

---

## What does not count as facilitation

- **A title that isn't exactly "Facilitator."**
- **A non-training event.** Attendance alone confers nothing.
- **A training the person didn't complete.** Only an **Attended** training confers
  facilitation. A no-show, a cancellation, a transfer out, or a **partial attendance**
  counts toward nothing: not New / Ongoing / Reinstated, not "Facilitators since", not
  Active / Formerly active.
- **A facilitator affiliation that starts and ends on the same day**, which is the
  trace a not-completed training leaves behind.

A partial attendance is still **kept on the record** — the affiliation and its
comments stay, and the organization still appears normally in that training's own
dashboard and report figures, because it was an active registration. What it doesn't
do is give the organization a facilitation period going forward.

On the org edit page, a training the org **only** registered for inactively gets a
**red attendance chip** — "No show", "Cancelled", "Transferred out" — instead of a
program status chip. If **anyone** from the org had an active registration at that
training, it keeps its normal program status chip.

---

## After a training: reconciling affiliations

Open the event → **Bulk actions → Reconcile affiliations**. Every facilitator
affiliation for a linked org is compared against attendance, a suggested outcome is
preselected, and every row also has a leave-it-alone option. **Preview changes** shows
what will happen before anything is written.

| Outcome | When it's offered | What it does |
|---|---|---|
| **Create new FA** | They attended but have no facilitator affiliation | Adds one, dated to the training |
| **Keep active** | Anything | Leaves the row alone |
| **Delete affiliation** | The row **this** training created, and they never turned up | Removes it — it recorded an assumption that never came true |
| **Deactivate affiliation** | An **older** row (hand-entered, or from an earlier training) | Ends it — never deletes it, because it records facilitation that really happened |
| **Reactivate** | A row this reconciliation previously ended, now that attendance says otherwise | Reopens it, with no lapse recorded |
| **Move to the new event** | They transferred to another training | Re-dates the affiliation to the new training instead of ending it |

Two rules worth knowing:

- **Endings land the day *before* the training.** A row that ended the same day
  another starts would count on both and double the person in any date total — and the
  row is being ended precisely because we have no record they completed a training
  there, so it must not still count as active on that date.
- **A transfer is not a failure.** The affiliation follows the person to the
  destination training rather than being ended.

Whatever reconciliation does, it leaves a **comment on the affiliation** saying why.

---

## Editing affiliations by hand — what moves what

| What you change | What it moves |
|---|---|
| **Start date** | History. It changes what the org reads at **every** training after that date |
| **End date** | History, the same way — and today's status once the date is past |
| **The Inactive flag** | Today's status only. Past verdicts don't move |
| **Deleting the row** | Both — the org reads as if that facilitation never happened |
| **The title** | Everything, if you're moving a row into or out of exactly "Facilitator" |

The **Inactive** flag exists so you can end someone effective *now* without inventing a
false end date — for example a one-day training that starts and ends today, where the
dates alone would still read as active for the rest of the day.

> Anything that changes a date is a change to the historical record that grant
> reporting rests on. Prefer the Inactive flag when you mean "they're done as of now,"
> and change dates only when the dates were wrong.

---

## Reading the reports

- **Event dashboard** — the New / Ongoing / Reinstated breakdown for that training,
  one count per organization, judged at that training's date. Only orgs with an
  **active** registration are counted.
- **Reports → Program status** — per training, grouped by year, with **two** counts,
  always labelled because they answer different questions:
  - **Organization-trainings** — one count per org per training. An org at three
    trainings in a year counts three times.
  - **Distinct organizations** — each org once for the period, classified at the
    **earliest** training it appeared at.
- **Attendees index** — spans events, so it is anchored on January 1 of the current
  year and says so.
- **Scholarships** — each award is judged at the training it paid for, so two awards
  side by side are read at their own events rather than at one page-wide "today".

---

## Quick answers

| "Why does this org…" | Because |
|---|---|
| …say **Never active** when someone's clearly linked? | Their title isn't exactly "Facilitator", or their only training was a no-show |
| …say **New** at a training it has attended before? | The earlier training didn't leave a facilitator affiliation — check for a red attendance chip on its edit page |
| …say **Reinstated** rather than Ongoing at a training? | Every earlier facilitator affiliation had ended before that date. Reconciliation ends rows the day before a training nobody completed, which produces exactly this |
| …read **Ongoing** in 2022 but **Formerly active** today? | Those are the two different questions. Both are correct |
| …show a **status mismatch warning**? | The legacy stored status field disagrees with the affiliations. The affiliations win; the warning is there to surface the drift |
| …have a **red chip** on a training? | Nobody from the org had an active registration there — no show, cancelled, or transferred out |

---

## Glossary

- **Affiliation** — a person ↔ organization link with a title and dates.
- **Facilitator affiliation** — an affiliation titled exactly "Facilitator"; the only
  kind that affects the organization's program status.
- **Job affiliation** — any other title; records the person's role, nothing more.
- **Anchor date** — the date a program status is judged on, normally a training's start
  date, otherwise January 1 of the current year.
- **Reconciliation** — comparing an event's facilitator affiliations against who
  actually attended, and creating / ending / deleting / moving them accordingly.
- **Inactive flag** — ends an affiliation as of now without changing its dates.

---

## Known gaps

- **A person's own page still shows the training.** The organization's figures ignore a
  not-completed training; the person's own facilitator dates are a separate question
  and are unchanged.
- **Old affiliation dates.** Rows created before mid-2026 may be dated to the 1st of
  the month rather than to the training, which can make an org read Ongoing at a
  same-month training where it should read New. Worth checking before trusting a
  historical year's "New" figures.

---

## For developers

The rules and the reasoning behind them are pinned in
[ADR-0001](adr/0001-organization-affiliation-and-program-status.md) (the figures, the
anchor date, the boundaries) and
[ADR-0003](adr/0003-affiliations-as-the-record-of-two-relationships.md) (what an
affiliation records, and what reconciliation may do to it).
