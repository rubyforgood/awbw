# This is a Ruby on Rails application.
<!-- Keep code style rules in sync with CLAUDE.md -->

For project overview, tech stack, architecture reference (models, controllers, services, testing), and more, read `AGENTS.md`.

## Setup

Full setup (bundle, npm, database create/migrate/seed):
```
bin/setup
```

If you just need frontend dependencies:
```
npm ci
```

## AI Instruction Files

When the user says "AI files", "AI instructions", "tell AI to", or "remember to always", these are the files.
If you notice the user repeatedly correcting the same pattern, suggest adding it to the AI files with a concrete proposal.

| File | Purpose |
|---|---|
| `CLAUDE.md` | Coding rules and conventions (this file) |
| `AGENTS.md` | Architecture reference + project details |
| `.github/copilot-instructions.md` | Coding rules for Copilot (duplicated from CLAUDE.md — keep in sync) |
| `ai/` | Shell script shortcuts for common dev tasks |

## Related Files

When changing a model or controller, check whether these related files need updates:

| If you change... | Also check... |
|---|---|
| Model | Decorator, policy, factory, model spec |
| Controller | Policy, request spec, routing spec, views |
| View | System spec, Stimulus controller (if interactive) |
| Service | Service spec |
| Decorator | Decorator spec |
| Mailer (add/remove) | Mailer spec, mailer preview (follow existing patterns) |
| Add/remove model, concern, service, or gem | AGENTS.md |

## Code Style

- Use modern Ruby syntax
- Prefer early returns and guard clauses
- Avoid unnecessary and/or complex conditionals
- Prefer constants and scopes over magic strings
- Use safe navigation (`&.`) where appropriate
- Use `presence` over blank checks
- Use `Arel.sql` for raw SQL in order clauses
- Avoid `update_all` unless explicitly intended
- Prefer service objects under app/services/
- Prefer POROs over concerns when possible
- Use `after_commit` instead of `after_save` for side effects

## RuboCop (rubocop-rails-omakase)

This project uses rubocop-rails-omakase. All code MUST follow these rules:

### Strings
- **Always use double quotes** for strings: `"foo"` not `'foo'`

### Spacing
- **Spaces inside array brackets:** `[ a, b, c ]` not `[a, b, c]` (empty arrays: `[]`)
- **Spaces inside hash braces:** `{ a: 1, b: 2 }` not `{a: 1}` (empty hashes: `{}`)
- **Spaces inside block braces:** `foo { bar }` not `foo {bar}` (empty blocks: `foo { }`)
- **No spaces inside parens:** `foo(bar)` not `foo( bar )`
- **No spaces inside reference brackets:** `hash[:key]` not `hash[ :key ]`
- **Space before block braces:** `foo { }` not `foo{ }`

### Commas
- **No trailing commas** in arrays, hashes, or method arguments

### Indentation
- **2-space indentation**, no tabs
- **Consistent indentation** at normal level — do NOT indent methods under `private`/`protected`
- **Align `end` with the variable** in assignments:
  ```ruby
  result = if condition
    value
  end
  ```
- **Align `when` with `end`**, not with `case`

### Whitespace
- **No trailing whitespace** on any line
- **No trailing blank lines** at end of file
- **No empty lines** inside class, module, method, or block bodies

### Syntax
- **Use `%w[]` and `%i[]`** with square bracket delimiters (not parens)
- **Use modern hash syntax:** `{ key: value }` not `{ :key => value }`
- **No redundant returns** — omit `return` on last expression
- **Use `flat_map`** instead of `.map { }.flatten`
- **No redundant `.to_s`** inside string interpolation
- **Use `Foo.method`** not `Foo::method` for method calls
- **No parentheses around conditions:** `if foo` not `if (foo)`
- **No semicolons** to separate statements
- **Use `format(...)`** for string formatting, not the `%` operator: `format("%.2f", amount)` not `"%.2f" % amount`

## Casing

- **Use sentence case** for UI labels, headings, and display text — not title case
- "Age range" not "Age Range", "Art type" not "Art Type"
- Use `.underscore.humanize` to convert PascalCase model/type names to sentence case (e.g., `"AgeRange".underscore.humanize` → `"Age range"`)
- Avoid `.titleize` for user-facing labels — it produces title case
- **Exception:** when a category type name prefixes a category name (e.g., "Age Range: 3-5"), use `.titleize` for the prefix

## Currency display

**Always display money with the `dollars_from_cents(cents)` helper** (`app/helpers/application_helper.rb`),
which delegates to the **`MoneyFormatter`** PORO (`app/services/money_formatter.rb`).
It takes an integer **cents** amount and renders `$1,500.50` when there are cents and `$1,500`
(no trailing `.00`) when the amount is a whole number of dollars. The helper is display-only — keep
storing and calculating in integer cents. For an abbreviated figure in tight UI (e.g. the grant
picker), use `MoneyFormatter.compact_from_cents(cents)` (`$12.5k`, `$1.2m`) — also cents-based.

- **Pass cents, not dollars.** Use the `*_cents` column/accessor (`amount_cents`,
  `amount_cents_remaining`, `allocation.amount`, etc.), not `amount_dollars`. Don't prepend a literal
  `$` — the helper includes it.
- **Do NOT use** `number_to_currency`, `format("%.2f", …)`, or the naked `"%.2f" % x` operator to show
  money. They always print `.00` and reintroduce the inconsistency this helper exists to remove.
  (`number_to_currency` is fine only inside the helper definition itself.)
- **In decorators**, call it via `h.dollars_from_cents(...)`; **in controllers**, via
  `helpers.dollars_from_cents(...)`. In a **model** or other PORO (no view-helper access), call
  `MoneyFormatter.dollars_from_cents(cents)` directly (e.g. validation messages) — don't fall back to
  `format("%.2f", …)`, which reprints `.00`.
- **Mirror the same rule in JavaScript** when a Stimulus controller renders a live money figure: drop
  the cents for whole-dollar amounts, keep two decimals otherwise (see `formatDollars` in
  `scholarship_preview_controller.js`). Keep the server-rendered initial value and the JS-updated value
  formatted identically.

## HTML/ERB Formatting

### Tag Attributes
- **Closing `>` on same line as last attribute** — do not put `>` on its own line
- When attributes span multiple lines, keep the closing `>` with the last attribute
- Example (GOOD):
  ```erb
  <div class="relative z-10 w-full bg-white text-gray-800 py-2 px-4"
       id="dropdown">
  ```
- Example (BAD):
  ```erb
  <div class="relative z-10 w-full bg-white text-gray-800 py-2 px-4"
       id="dropdown"
  >
  ```

## Navigation & back links (eyebrows)

The "eyebrow" is the back/return link in a page's top bar (e.g. `← Registrants`).
**Whenever you add a link from one page to another, think through the eyebrow on the
destination** — the user must be able to return to exactly where they came from, not a
generic default. This applies to any navigation, and matters most for links that open in
a new tab (`target: "_blank"`), where the browser back button is useless. When a page is
reachable from several origins, the eyebrow must adapt to whichever one the user came from.

- **Pass a `return_to` param** from the originating link identifying the origin context.
  The destination's eyebrow branches on `params[:return_to]` to build the correct back
  link, falling back to a sensible default when it's absent or unrecognized.
- **Preserve UI state on return.** If the origin had an expanded row, open accordion,
  active tab, scroll position, or filter, pass enough params to restore it — an identifier
  to re-open the element **and** an `anchor:` fragment so the browser scrolls to it. The
  target element needs a matching `id` and a `scroll-mt-*` utility so it isn't hidden under
  sticky headers.
- **Carry whatever the destination can't infer.** If the back link needs context the
  destination doesn't already have (e.g. linking to a record that isn't scoped to the
  origin's parent), pass that too (an `event_id`, a parent slug, etc.).
- **Keep both ends in sync.** When you change what a `return_to` value means, update every
  page that consumes it. Controller `case params[:return_to]` redirects (after save/destroy)
  and the view eyebrow should agree on where a given origin returns to.
- **Reuse, don't reinvent.** Match the mechanism already used by nearby flows, and extract a
  helper when the same back-link is built in more than one destination (e.g.
  `EventHelper#bulk_payments_return_path` centralizes the expand + anchor logic for the bulk
  payments flow).

## Page background class (`page_bg_class`)

Every page view sets `<% content_for(:page_bg_class, "...") %>` at the top — the layout
(`app/views/layouts/application.html.erb`) renders it on the main content wrapper. The class
string is a **semantic policy marker** matching the page's authorization level (e.g. `"public"`,
`"admin-or-auth"`, `"admin-or-owner"`, `"admin-only bg-blue-100"`), not just a Tailwind class.

**Whenever you add a new page (a new `*.html.erb` view rendered as a full page), check whether
it needs a `page_bg_class` and register it:**

- **Set `content_for(:page_bg_class, "...")`** at the top of the new view, choosing the marker
  that matches the controller action's policy (compare against the relevant `*_policy.rb`).
- **Add the view path → expected value to `EXPECTED_MAPPINGS`** in
  `spec/views/page_bg_class_alignment_spec.rb`. A test asserts every view that sets
  `page_bg_class` is listed there (and matches its policy), so the suite fails if you skip this.
- **Match neighboring pages.** Use the same marker as sibling views with the same authorization
  level rather than inventing a new value.

## Lazy index/filter frames

Filterable index pages load their rows lazily in a Turbo frame so changing a
filter swaps just the results, not the whole page (grants, people, users,
organizations, stories, community_news, video_recordings, monthly_reports,
bookmarks, payments, resources, workshops, notifications, allocations all follow
this). Match the existing pattern:

- `index.html.erb` renders the header, the filter/search form, and a skeleton
  inside `<%= turbo_frame_tag :<resource>_results, src: result_src, data: { turbo: "temporary" } %>`.
- The controller `index` branches on `turbo_frame_request?`: the frame request
  builds the filtered/paginated scope and renders the results view; otherwise it
  renders the full `index`.
- **Name the frame-response view after its Turbo frame tag id** — the
  `turbo_frame_tag` id, the controller render target, and the view filename are
  one shared `<resource>_results` token (e.g. `turbo_frame_tag :grants_results` ←
  `render :grants_results` ← `app/views/grants/grants_results.html.erb`). This
  keeps the view discoverable from the frame tag, and `_results` reflects that the
  frame holds the filtered result set. **Never name it `index_lazy`** — that old
  name has been removed.
- **Never change a frame tag id to rename a view.** Turbo matches on the id, so
  it must stay identical across `index.html.erb`, the results view, the filter
  form's `data-turbo-frame`, request-spec `Turbo-Frame` headers, and
  `turbo-frame#…` view-spec selectors. Only the filename and render target change.

## JavaScript

- ES6+ syntax, ESM imports/exports, `const`/`let` (no `var`)
- Use `const` for fixed values — not `SCREAMING_SNAKE_CASE` constants (e.g., `const styleId = "foo"` not `const STYLE_ID = "foo"`)
- **Strongly prefer Stimulus** for JavaScript behavior — do not write raw/inline JS or jQuery
- **Always use Tailwind CSS** utility classes for styling — do not write custom CSS unless absolutely necessary
- **Prefer Font Awesome (free)** icons over inline SVGs — use `icon("fa-solid fa-foo")` helper. Inline SVGs are acceptable when a specific icon design is preferred.
- Prefer Turbo for navigation and form submissions before reaching for Stimulus
- Controller naming: `[name]_controller.js`
- Keep controllers focused and small
- **Before adding a new JS/Stimulus controller, check whether an existing one already covers the behavior or can be lightly adapted** — search `app/frontend/javascript/controllers/` for similar names/behavior (e.g. sorting, toggling, autocomplete). Prefer reusing it, or generalizing it with a new value/target/class so both callers share it, over creating a near-duplicate. Only add a new controller when the behavior is genuinely distinct. If a small change to an existing controller would make it reusable, do that (and re-verify its existing callers)

### Stimulus Conventions

Follow the [Stimulus Handbook](https://stimulus.hotwired.dev/handbook/introduction) and reference docs. Key rules:

**Targets over querySelector** — declare `static targets = [...]` and use `data-[controller]-target` attributes in views. Never use `this.element.querySelector` or `document.getElementById` to find elements that could be targets. Exception: elements outside the controller's scope (e.g., in a parent view).

**Values API for state** — use `static values = { name: Type }` for any state that persists or drives UI. Do not store state in instance variables when a value would work. Use `[name]ValueChanged()` callbacks for reactive updates instead of manual syncing.

**Actions over manual listeners** — use `data-action` attributes instead of `addEventListener` in `connect()`. Omit the event when it's the default for the element (`click` for buttons/links, `input` for inputs/textareas, `submit` for forms, `change` for selects). Use `@window` or `@document` suffixes for global events when possible (e.g., `resize@window->controller#layout`). Use action options like `:prevent` and `:stop` instead of calling `event.preventDefault()` in methods.

**Classes API for CSS** — use `static classes = [...]` when CSS classes need to be configurable from HTML. For standard Tailwind utilities used internally (e.g., `"hidden"`), hardcoding is acceptable.

**Outlets for cross-controller communication** — use `static outlets = [...]` to reference other controllers instead of `document.getElementById` or custom events when the relationship is stable.

**Lifecycle discipline** — every listener, timer, or observer created in `connect()` must be cleaned up in `disconnect()`. Store bound handler references so they can be removed. Use `initialize()` for one-time setup (e.g., binding functions).

**Target lifecycle callbacks** — use `[name]TargetConnected(element)` and `[name]TargetDisconnected(element)` to respond to dynamically added/removed targets (e.g., cocoon nested fields, Turbo streams).

**Visibility** — toggle the `hidden` class via `classList.toggle("hidden", condition)` instead of setting `style.display`. Use `class="hidden"` in HTML for initial hidden state, not `style="display:none"`.

## Migrations

- Name migration files using the **actual current UTC timestamp down to the second** — generate it (`date -u +%Y%m%d%H%M%S`), don't hand-write the number. The minutes and seconds (`…HHMMSS`) must be real, not zero-padded.
- **Never use round, zero-trailing times** like `20260618030000` or sequential numbers like `20260228000007`. They collide when two branches add a migration the same day, because everyone gravitates to the same round number. Real second-level timestamps (e.g. `20260618034355`) effectively never collide. (This has bitten us: two PRs both shipped `20260618020000`.)
- **Migrations must be reversible** — always use explicit `up`/`down` methods instead of `change` when the rollback isn't trivially invertible. Guard `down` operations with `if_exists: true`, `column_exists?`, `index_exists?`, and `foreign_key_exists?` so rollbacks are idempotent and recover from partial failures

## Git

- Default branch is `main`
- Commit messages should explain why, not what
- CI runs via GitHub Actions (`.github/workflows/`)
- **When rebasing onto main**, review incoming changes for their intent and flag any oversights — missing tests, incomplete migrations, broken assumptions, or conflicts between the two branches. Check both directions: schema/model changes on either branch that affect views, partials, or layouts on the other (e.g., main redesigned a table's CSS but your branch adds new columns to it, or vice versa)

## PRs

- **Always create PRs as drafts** — every PR starts in draft (`gh pr create --draft`), no exceptions. Never open a PR ready for review, and never promote it. Only the user runs `gh pr ready`, manually and intentionally, when they decide the work is ready.
- **Push to a draft PR early** — create the draft PR as soon as work begins, rather than keeping changes in a local branch. Push on every commit.
  - **In a new Conductor workspace, do this immediately** — as the first step of any task, make an initial commit on the workspace branch and open the draft PR right away (before the work is done), then keep pushing on every commit as you go. Don't wait until there's a finished change to show.
- **Never take a PR out of draft** — do not run `gh pr ready` or otherwise remove draft status, even after the work looks complete. Leave the PR in draft; the user promotes it manually and intentionally when they decide it's ready.
- **Do not rename branches after creating a PR** — deleting the old remote branch auto-closes the PR on GitHub, and the head ref cannot be changed after creation
- Use `docs/pull_request_template.md` for PR description structure
- **Remove the `Closes …` line when there's no ticket** — it's a template placeholder. Keep it (with a real issue link) only when the PR closes a tracked ticket; otherwise drop the line entirely rather than leaving the placeholder.
- **Keep descriptions as short as possible** — a few terse bullets, not paragraphs. Cut anything a reviewer can see from the diff; only keep what explains *why*.
- **Start the description with a review-depth tag** on its own single line, prefixed with `🤖 PR, suggested 👤 review level: `, followed by a blank line, then the rest of the description. The tag is the prefix, the icon, the level name, and the short note on what that level means — e.g. `🤖 PR, suggested 👤 review level: 👀 Skim — view-only: markup/copy/styling, no logic or data changes`. Always spell out the meaning inline; never post the icon and name alone. The tag tells the reviewer how closely to look (depth of review, not how risky/good the change is):
  - **👀 Skim** — view-only: markup/copy/styling, no logic or data changes
  - **📖 Read** — light-logic: small, contained logic changes with low blast radius
  - **🔬 Inspect** — big change: substantive logic, migrations that rename or transform data (backfills), or wide-reaching changes that warrant careful review
- Use bullet points, not paragraphs, when filling out each section
- Description must explain why the change was made, not just what
- Include screenshots for UI changes
- **On every push**, update the PR title and content to reflect the current diff — preserve any existing images/screenshots in the description
- **On every push**, update AI instruction files if the diff adds, removes, or renames anything tracked in AGENTS.md — specifically: Stimulus controllers, services, model/controller concerns, mailers, rake tasks, and directory file counts
- **On every push**, add PR review comments on notable lines of code — decisions, trade-offs, non-obvious logic, or anything a reviewer should understand. Use `gh api` to post line comments on the diff
- **Attribute every AI-authored GitHub comment** — `gh` posts as the authenticated user, so any comment you create (PR review comments, issue/PR comments, replies) MUST be prefixed to identify the AI agent that wrote it. Begin the comment body with `🤖 _From <agent>:_` (e.g. `🤖 _From Claude:_` or `🤖 _From Copilot:_`) followed by the content
- **Keep GitHub comments short and to the point** — one or two sentences, stating the key insight directly. Skip preamble, restating the code, and hedging; if a comment needs more than a few lines, it usually belongs in the PR description instead

## Testing

- **Bug fixes require a failing test first** — before writing any fix code, write a test that reproduces the bug and confirm it fails. Only then write the code to make it pass.
- Follow the red-green-refactor cycle: failing test, minimal fix, then refactor
- Be careful with system/JS tests — avoid patterns that lead to flakiness

## Session recap

When the user says **"recap"**, **"ai recap"**, or runs **`ai/recap`**, review the full conversation and report two parts:

1. **Recap** — what was accomplished this session.
2. **Unresolved** — dropped threads, unanswered questions, unfinished tasks, and unresolved disagreements (from either side).

This is an agent task — NOT the `/audit` skill (design/accessibility review, only on an explicit `/audit`) and NOT `ai/security` (the security scan). The `ai/recap` script only emits the trigger word; the agent does the work per this section.

**Format the Unresolved part as a bulleted list with a count header.**

If nothing is unresolved:
```
- Nothing unresolved
  - All tasks completed, questions answered, and threads closed
```

If there are unresolved items:
```
- 3 unresolved items below
  - 1. Item title
    - Description of what's unresolved
  - 2. Item title
    - Description of what's unresolved
  - 3. Item title
    - Description of what's unresolved
```

### After submitting a PR

After creating or submitting a pull request, automatically perform the session recap (Recap + Unresolved) using the format above.

## Quick Commands

See `ai/` directory for executable scripts:

| Command | What it does |
|---|---|
| `ai/recap` | Session recap: accomplishments + unresolved items (see above) |
| `ai/review` | Code review: agent reviews the workspace diff, posts inline comments, and gives a Recap + Risks + Outstanding decisions summary (runs the `ai-review` skill) |
| `ai/test [args]` | Run RSpec |
| `ai/lint` | Rubocop on all files |
| `ai/lint --fix` | Auto-fix lint issues |
| `ai/server` | Start dev services (web + vite) |
| `ai/console` | Rails console |
| `ai/routes -g pattern` | Search Rails routes |
| `ai/migrate` | Run database migrations |
| `ai/seed` | Load the full dev sample dataset (`db:seed:dev`) into the workspace DB |
| `ai/security` | Security scan: Brakeman + bundler-audit (mirrors CI) |

> **"ai <name>" means the `ai/` script of that name** (e.g. "ai test" → `ai/test`, "ai security" → `ai/security`) — shell scripts in `ai/`, not slash-command skills. If a referenced `ai/<name>` script doesn't exist, ask what's intended rather than substituting a similarly named skill. Two are special — they print a trigger word, and the agent does the work directly rather than producing script output: (1) **"ai recap"** triggers the **Session recap** behavior above; never confuse it with the `/audit` design skill or the `ai/security` scan. (2) **"ai review"** (`ai/review`) triggers the **`ai-review` skill** — review the current workspace diff, post one inline comment per qualifying bug, then give a Recap + Risks + Outstanding decisions summary; it is not the `/audit` skill or the `/code-review` / `/review` skills.
