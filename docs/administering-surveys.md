# Administering training surveys (Day 1, Day 2, Post-event & Recipients)

You can now administer forms (surveys) through the Ticket! This doc walks through how
the training surveys reach registrants, what was set up for you automatically, and how
to change any of it yourself.

If a step below says "ask a developer," that's a one-time technical task; everything
else you can do from the Portal.

---

## The big idea

A **survey is just a form.** It becomes a survey when you attach it to a **callout**
on the registration ticket. A callout is one of the cards a registrant sees on their
ticket (like Payment, Handouts, or Scholarship).

So there are two pieces:

1. **The form** — the questions (e.g. "Day 1 Survey").
2. **The callout** — the card on the ticket that *delivers* the form and decides
   *when* it opens.

Everything below is about connecting those two and choosing timing.

---

## What was set up for you automatically

When the surveys were first turned on, a one-time seed created these **four form
templates** (a developer runs this once — the task is `data:seed_survey_forms`):

| Form | Who it's for | Where it lives |
|---|---|---|
| **Day 1 Survey** | Everyone | Feedback surveys callout |
| **Day 2 Survey** | Everyone (multi-day trainings) | Feedback surveys callout |
| **Post-Event Survey** | Everyone | Feedback surveys callout |
| **Post-Training Recipients Survey** | Scholarship recipients only | Scholarship callout |

It also set up two **built-in callouts** on every event:

- **Feedback surveys** — carries the Day 1, Day 2, and Post-Event surveys for
  *everyone*, each opening on its own date.
- **Scholarship** — carries the Recipients survey, shown *only to scholarship
  recipients* after they've finished their scholarship steps.

These are **starting points you can edit.** Nothing is locked. Changing a form or a
callout for one event only affects that event.

---

## Turning surveys on for an event

Built-in callouts start **hidden** so registrants don't see them before you're ready.

1. Open the event and go to its **edit page**.
2. Scroll to the **registration ticket callouts** section.
3. Find the **Feedback surveys** callout (and **Scholarship**, if the event has
   scholarship recipients).
4. Flip the **Published** toggle on to show it on the ticket.
5. **Save** the event.

That's it — the callout now appears on every registrant's ticket, and each survey
inside it opens on its scheduled date.

> **Tip:** If you don't see the Feedback surveys callout yet, just opening the
> event's edit page adds it. If it looks different from the defaults and you want to
> start over, use **Restore default** on that callout.

---

## Choosing when each survey opens (drip dates)

Inside a callout's editor there's a **Linked forms** area. Each row is one survey:
a **form** and a **Display date**.

- **Display date set to a future date/time** → the survey stays closed until then.
  On the ticket the registrant sees the survey with an **"Available on <date>"**
  chip; they can't fill it early.
- **Display date left blank** → the survey is open right away.

The defaults are: Day 1 opens ~30 min before the end of day 1, Day 2 ~30 min before
the end of day 2, and the Post-Event survey ~30 min before the event ends. **Change
any of these** by editing the Display date and saving.

To **add** another survey to the callout, click **➕ Add form**, pick the form, set a
date. To **remove** one, click the ✖ on its row.

---

## Editing the survey questions

To change the questions themselves, edit the **form**:

1. Open the form (from the form list, or the form linked on the callout).
2. Use the tabs at the top:
   - **Preview** — see the form exactly as a registrant will.
   - **Edit** — change question text, add/remove questions, reorder, mark required.
   - **Edit sections** — rearrange whole sections.
   - **Results / Submissions** — see who answered and what they said.

Edits to a form apply everywhere that form is used. If you want a one-off version for
a single event, use **Duplicate form** first and edit the copy.

---

## The "Fan out per resource" feature (per-topic questions)

Some questions are asked **once per workshop/topic** — for example
*"This workshop supported my personal growth:"* repeated for each workshop. Rather
than copy-paste the question many times, we link the question to **resources** (the
workshops/topics), and the form repeats it automatically, adding the topic name to
the end of the prompt.

To set this up on a question:

1. Edit the form and find the question.
2. Open the **Fan out per resource** section under it.
3. Click **➕ Add resource** and search for each workshop/topic to include.
4. Save.

The form now shows that one question once per linked resource. To change which topics
appear, add or remove resources here. (The starter surveys already have a sensible
default set — adjust it to match your curriculum.)

> The topics are **Resources** in the Portal. In production they already exist; if a
> topic you want isn't there, create the Resource first, then link it.

---

## The scholarship recipients survey (special rules)

The **Recipients survey** is different from the everyone-facing surveys:

- It lives on the **Scholarship** callout, so **only scholarship recipients** ever
  see it.
- It appears on the recipient's **scholarship page**, and only **after** they've
  **signed their scholarship agreement** and their **scholarship tasks are marked
  complete** (plus any Display date you set).
- It's the survey that **gates a recipient's certificate** — until they submit it (or
  you mark it received on the registration edit page), they show as **"Survey
  pending"** on the registrants list and can't be completed.

So for recipients, the order is: accept the award → finish tasks → the survey opens →
they submit it → they can receive their certificate.

---

## What a registrant sees and does

On their ticket, the Feedback surveys card links to a page listing each survey:

- **Not open yet** → a collapsed row with an **"Available on <date>"** chip.
- **Open** → the questions, ready to fill.
- **Completed** → a collapsed **"Completed"** toggle. They can expand it to review
  their answers and click **Edit responses** to change them.

They can edit their answers any time after submitting.

---

## Getting notified

Every time someone submits (or edits) a survey, staff get a heads-up email at the
default notifications address, listing the answers. The **subject** says **"New"**
for a first submission and **"Updated"** when the registrant edits their answers, so
you can tell them apart at a glance.

---

## Quick glossary

- **Form** — the set of questions.
- **Callout** — a card on the registration ticket that delivers a form and decides
  when it opens.
- **Linked forms** — the forms a callout carries, each with its own Display date.
- **Display date** — when a survey opens (blank = open now).
- **Published** — whether the callout shows on the ticket at all.
- **Fan out per resource** — repeat one question once per linked topic/workshop.
- **Restore default** — reset a built-in callout back to its seeded starting point.

---

## Common tasks at a glance

| I want to… | Do this |
|---|---|
| Show the surveys on tickets | Publish the **Feedback surveys** callout on the event, save |
| Change when a survey opens | Edit its **Display date** under **Linked forms** |
| Open a survey immediately | Clear its **Display date** |
| Add another survey to the card | **➕ Add form** under Linked forms, pick a form + date |
| Change the questions | Open the form → **Edit** |
| Preview what registrants see | Open the form → **Preview** |
| Ask a question per workshop | On the question, **Fan out per resource** → add topics |
| Reset a callout to defaults | **Restore default** on that callout |
| See who answered | Open the form → **Results / Submissions** |
