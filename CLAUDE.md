# This is a Ruby on Rails application.
<!-- Keep code style rules in sync with .github/copilot-instructions.md -->

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

## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues, via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context — one `CONTEXT.md` + `docs/adr/` at the repo root (created lazily by `/domain-modeling`). See `docs/agents/domain.md`.

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
| Ship a user-facing feature **or improvement/change** | `config/features.yml` (the Features & tips seed — see below) |

## Code Style

- Use modern Ruby syntax
- Prefer early returns and guard clauses
- Avoid unnecessary and/or complex conditionals
- Prefer constants and scopes over magic strings
- Avoid Rails `enum` — prefer plain string columns constrained by a constant + `validates inclusion`
- Use safe navigation (`&.`) where appropriate
- Use `presence` over blank checks
- Use `Arel.sql` for raw SQL in order clauses
- Avoid `update_all` unless explicitly intended
- Prefer service objects under app/services/
- Prefer POROs over concerns when possible
- **In service objects and POROs, read constructor arguments from instance variables (`@foo`) — don't add `private attr_reader`** for them. Reserve `attr_reader` for values the object deliberately exposes to callers (e.g. `BulkInviteService#results`).
- **Prefer decorators (Draper, app/decorators/) over view helpers for model-specific presentation** — when display logic is "about a record" (labels, badges, formatted attributes, status pills), put it on that model's decorator and call `record.decorate.thing`. Reserve `app/helpers/` for generic, cross-model view utilities that aren't tied to one model. Decorators keep presentation testable and out of ERB.
- Use `after_commit` instead of `after_save` for side effects
- **Don't pass `to:` to `authorize!` when the rule matches the controller action** — ActionPolicy infers the rule from the action name (`create` → `create?`, `update` → `update?`), so `authorize! @record` in the `update` action already checks `update?`. Only pass `to:` when checking a *different* rule than the current action (e.g. `authorize! @scholarship, to: :update?` from a non-`update` action, or `authorize! :workshop, to: :summary?`).
- **Default to no comment.** Most code should carry none — clear names and small methods explain themselves. Only add a comment for a genuinely non-obvious *why* or a gotcha that would trip up the next reader, and only when you can't make the code say it instead (a better name, a named constant, an extracted method). Never restate what the code already says, and don't comment a constant, scope, or step whose intent is clear from its name. When a comment truly earns its place, keep it to **one line**; let it run longer only when the logic is genuinely complex and the reasoning can't be inferred from the code plus domain knowledge.

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

## Domain colors (DomainTheme)

Each domain (workshops, organizations, events, forms, sectors, scholarships, …) has one
canonical Tailwind color, mapped in **`DomainTheme::COLORS`** (`lib/domain_theme.rb`). The
point is single-source theming: re-coloring a whole domain is a one-line change in `COLORS`.

- **Never hard-code a domain's own identity color.** When a panel, badge, chip, button, link,
  or icon is themed to a domain, resolve the class through `DomainTheme`, not a literal like
  `bg-emerald-50` / `text-indigo-700` / `hover:text-purple-800`.
- **Helpers** (all take a domain key symbol, e.g. `:organizations`):
  - `DomainTheme.bg_class_for(key, intensity: 50, hover: false)` → `"bg-emerald-50"` (`hover: true`
    prefixes `hover:bg-` and bumps one step).
  - `DomainTheme.text_class_for(key, intensity: 800, hover: false)` → `"text-emerald-800"`
    (**`hover: true` prefixes `hover:text-`** at the intensity you pass — use it for link hover
    states instead of a literal `hover:text-*`).
  - `DomainTheme.border_class_for(key, intensity: 300)` → `"border-emerald-300"`.
  - `DomainTheme.color_for(key)` → the raw color symbol (e.g. `:emerald`); unknown keys fall back
    to `:gray`.
- **In views** interpolate the helper into the class list (`<%= DomainTheme.bg_class_for(:forms) %>`);
  **in decorators/POROs** (no helper access) call `DomainTheme.…` directly — it's a plain module.
- **New color?** Add the key → color to `DomainTheme::COLORS` **and** add the color to the
  `@source inline(...)` safelist in `app/frontend/stylesheets/application.tailwind.css`, or Tailwind
  won't generate the dynamically-built class and it renders unstyled.
- **Leave genuinely non-domain colors literal** — don't force these through `DomainTheme`: the
  `bg-blue-100` `page_bg_class` marker, the global `focus:border-blue-500 focus:ring-blue-200`
  form-focus convention, status colors (green = success, amber/yellow = warning, red = error),
  multi-color pickers/swatches, and classes a Stimulus controller also toggles (keep ERB and JS in
  sync as literals). Convert only a domain's *own identity* color.

## Sharing repeated Tailwind (avoid `@apply`)

When the same utility string is repeated across many views, **unify it with a Rails view
helper or a shared partial — not `@apply`.** `@apply` hides the utilities inside a CSS rule
and creates the indirection the tailwind-best-practices guidance warns against; a helper
keeps the utilities scannable (Tailwind already scans `app/helpers`) and reads as a real
template abstraction.

- **Helper returning a class string** — the same shape as the `DomainTheme.*_class_for`
  helpers. Return only the *shared* fragment (e.g. a color pair) and let each caller keep its
  own context-specific layout classes. Example: `eyebrow_link_class` returns the muted gray for
  page eyebrows / back-nav links; views interpolate it
  (`class: "text-sm #{eyebrow_link_class} px-2 py-1"`).
- **Shared partial** — when the repeated thing is markup (icon + text + structure), not just a
  class list.
- **`@apply` is reserved** for genuine element/base styles (e.g. `.btn` in
  `components/buttons.css`), not for extracting repeated utility clusters.

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

## Form submission displays

**A form submission's answers are shown on several different pages — know which is which
before linking between them.** They share the answer-display partials
(`form_submissions/submission`, `shared/form_answer_value`, the section grouping), so keep
presentation in those partials, not forked per page.

- **"Public submission" / "public form display" = the person's own slug-accessible view of
  their submission, reached through the ticket** (and linkable from lists). Today that's the
  event **public registration confirmation** (`events/public_registrations#show`,
  `page_bg "public"`), accessed publicly via `?reg=<registration_slug>` (the unguessable
  ticket token) or, for admins, `?person_id=` (gated by `person_form_submission?`). When
  someone says "public form display," this is what they mean — **not** the admin `show`.
- **Admin submission views** (both `page_bg admin-only`; both carry the admin-only "What this
  submission changed" bar when `FormSubmissionChanges#edited?`):
  - `form_submissions#show` — top-level `/form_submissions/:id` (admin-or-slug).
  - `events/form_submissions#show` — event-scoped registrant submissions ("← Back to registrants").
- **Link-organizations pages** (admin) also render a submission summary and the changes link:
  `event_registrations/link_organization` and `form_submissions/link_organization`.
- The **"What this submission changed"** audit page is `form_submissions#changes` (admin-only);
  its eyebrow branches on `params[:return_to]` to return to whichever page linked in.
- **Standalone (non-event) submissions currently have no submitter-facing view** — tracked in
  rubyforgood/awbw#2407 (confirmation email → slug-based own-view reusing these partials).

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
bookmarks, payments, resources, workshops, notifications, allocations, features all
follow this). Match the existing pattern:

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
- **The results response must never 500 — a raise becomes "Oopsie!".** When the
  frame request errors (or returns a document without the matching frame), the
  `turbo:frame-missing` handler (`app/frontend/javascript/turbo-events.js`)
  swaps the frame for an "Oopsie! Something went wrong" box — the row data just
  vanishes, with no server error page to hint why. The usual culprit is a
  **row/card partial dereferencing a nil association** (an `optional:`/polymorphic
  FK, an account-less `person`, a not-yet-linked `event`/`organization`,
  `created_by`/`updated_by`): use safe navigation (`&.`) or a decorator fallback
  for anything that can realistically be nil, and remember these lists routinely
  include edge-case records the happy-path factory doesn't. **Cover it with a
  request spec that sends the `Turbo-Frame` header and includes the nil-association
  record**, asserting `:ok` and that the body contains the frame id — a plain
  full-page `get` in a spec won't reproduce a frame-only failure the same way.
- **A link inside the results frame that navigates *away* must break out with
  `data: { turbo_frame: "_top" }`** (or the whole frame needs `target: "_top"`).
  Otherwise Turbo loads the destination *into* the results frame; the destination
  has no matching frame, so it's the same `turbo:frame-missing` "Oopsie!". Row
  links to detail/edit pages (grants, people, organizations, workshops, resources,
  video_recordings all do this) carry `_top`; only in-frame drivers that *should*
  stay — pagination, the filter form (which drives the frame from outside), and
  in-card forms answering with turbo streams — omit it. When a results frame's
  cards contain several such links, prefer `turbo_frame_tag :x_results,
  target: "_top"` so no link can be forgotten.

## Features & tips page (`/features`)

The login-gated **Features & tips** page lists shipped, user-facing features
(newest first, filterable by area/audience/date) so facilitators and admins can
see what the portal does. It is **database-backed** (`Feature` model) and edited
in-app by super-admins — the rich `description` uses the Rhino WYSIWYG (so pages
can carry screenshots), and each feature can link an external process doc.

**Keep it current as you ship.** When you ship anything a facilitator or admin
would want to know about, append an entry to `config/features.yml` (the checked-in
**seed**). This is **not just brand-new features** — a user-facing *improvement,
change, or enhancement* to something that already exists (a new filter, an extra
column, a reworked flow) belongs here too. If in doubt whether a change is "big
enough," add it: a short entry is cheap and the page is where non-devs discover
what changed.

- **There is no separate "feature vs. update" flag** — every entry is just a
  `Feature` row, and audience is the only axis (`display_status`). Signal that an
  entry is a smaller update through its `summary`/`name` wording (e.g. "Filter
  registrants by registration date"), not a schema field. (If we ever want the UI
  to visually separate launches from tweaks, that's a `kind:` column on `Feature` +
  `CATALOG_FIELDS` + a decorator badge — a deliberate change, not something to
  fake with `area`/`display_status`.)
- Fields: `name`, `area` (a `Feature::AREA_KEYS` value), `display_status`
  (`public_facing` / `user_facing` / `admin_facing`), `summary` (1–2 plain
  sentences), `released_on` (ship date), plus optional `pro_tips` (list),
  `description` (longer HTML/text), `external_url`, `action_path` (in-app path for
  the detail page's "Check out this feature" link), and `pr_number` (adds a
  GitHub PR link).
- **Sentence case, plain language** — this page is read by facilitators, not devs.
- `admin_facing` features are visible to super-admins only (`FeaturePolicy` gates
  this in its relation scope, not just in the UI).

An admin clicks **Sync latest updates** on `/features` (`FeatureCatalog#import!`,
matched by `name`) to pull newly-shipped features from the seed, **re-align the
catalog-owned classification** on existing records (`CATALOG_FIELDS` — area,
`display_status`, `released_on`, `action_path`, `pr_number`, so a seed fix like a
wrong audience propagates), **and fill in blank content** (`CONTENT_FIELDS` —
`summary`, `pro_tips`, `external_url`, `description`) without ever overwriting what
an admin wrote.

- **New area?** Add it to `Feature::AREAS` (label + Font Awesome icon + a Tailwind
  hue already safelisted in `application.tailwind.css`) and use its key in the
  seed. Area/audience presentation (badges/labels) lives on `FeatureDecorator`.

## JavaScript

- ES6+ syntax, ESM imports/exports, `const`/`let` (no `var`)
- Use `const` for fixed values — not `SCREAMING_SNAKE_CASE` constants (e.g., `const styleId = "foo"` not `const STYLE_ID = "foo"`)
- **Default to no new JavaScript.** Prefer a server-rendered (ERB/decorator/helper) or Turbo solution over adding a new Stimulus controller. Only reach for JS when the behavior genuinely can't be done server-side or with Turbo (e.g. it needs live client-side state, the browser's own time zone, or DOM the server can't produce). If a change seems to need JS, first ask whether rendering it on the server — even with a small trade-off — is acceptable, and flag that trade-off. When JS is truly required, reuse or generalize an existing controller before writing a new one.
- **Strongly prefer Stimulus** for JavaScript behavior — do not write raw/inline JS or jQuery
- **Always use Tailwind CSS** utility classes for styling — do not write custom CSS unless absolutely necessary
- **Prefer static Tailwind classes over dynamically-constructed ones.** Tailwind's JIT scanner only generates classes it finds as complete literal strings in the source — a class built by interpolation (e.g. `bg-#{color}-500`, `text-${size}`, `class="w-#{n}"`) won't be generated and silently renders unstyled. Write the full class names out, and select between complete literals (e.g. a lookup hash mapping a value to a whole class string, or a ternary picking between two literal classes) rather than splicing fragments. Only build a class dynamically when the set of values is open-ended and can't be enumerated; in that case add the candidates to the Tailwind safelist.
- **Prefer Font Awesome (free)** icons over inline SVGs — render them as markup: `<i class="fa-solid fa-foo"></i>`. Inline SVGs are acceptable when a specific icon design is preferred; the `icon("name")` helper (`app/helpers/icon_helper.rb`) inlines a local SVG from `app/frontend/icons/` by filename — it is not a Font Awesome helper.
- Prefer Turbo for navigation and form submissions before reaching for Stimulus
- Controller naming: `[name]_controller.js`
- Keep controllers focused and small
- **Before adding a new JS/Stimulus controller, check whether an existing one already covers the behavior or can be lightly adapted** — search `app/frontend/javascript/controllers/` for similar names/behavior (e.g. sorting, toggling, autocomplete). Prefer reusing it, or generalizing it with a new value/target/class so both callers share it, over creating a near-duplicate. Only add a new controller when the behavior is genuinely distinct. If a small change to an existing controller would make it reusable, do that (and re-verify its existing callers)

### Stimulus Conventions

Follow the [Stimulus Handbook](https://stimulus.hotwired.dev/handbook/introduction) and reference docs. Key rules:

**Targets over querySelector** — declare `static targets = [...]` and use `data-[controller]-target` attributes in views. Never use `this.element.querySelector` or `document.getElementById` to find elements that could be targets. **This includes CSS-class lookups: don't select elements by a marker/hook class (`querySelectorAll(".foo-view")`), and don't pass CSS class names in as `Values` to query by — mark the elements as targets and iterate `this.fooTargets` instead.** When two target sets line up one-to-one (e.g. `viewTargets`/`editTargets`), pair them by DOM order. Exception: elements outside the controller's scope (e.g., in a parent view). (Part of the ongoing Stimulus-conventions audit, rubyforgood/awbw#1392.)

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
- **Don't follow, poll, or wait on CI.** After pushing or opening/updating a PR, never run `gh run watch`, `gh pr checks`, or spawn a background task to poll a CI run to completion. The user watches CI themselves. Push, report what you did, and end the turn — don't burn tokens waiting on the run.
- **When rebasing onto main**, review incoming changes for their intent and flag any oversights — missing tests, incomplete migrations, broken assumptions, or conflicts between the two branches. Check both directions: schema/model changes on either branch that affect views, partials, or layouts on the other (e.g., main redesigned a table's CSS but your branch adds new columns to it, or vice versa)

## PRs

- **"Prefix" / "add prefix X" refers to the PR title.** When the user mentions "a
  prefix" or says "add prefix X" (e.g. `MAYBE:`, `JM:`) and it doesn't fit whatever
  you're currently working on, they mean a leading tag on the **pull request title**
  (often auto-added). For "add prefix X", prepend that literal string to the current
  title, preserving the rest; for "remove the X prefix", strip it. Act via `gh pr
  edit --title`, never on code or commit messages.
- **Always create PRs as drafts** — every PR starts in draft (`gh pr create --draft`), no exceptions. Never open a PR ready for review, and never promote it. Only the user runs `gh pr ready`, manually and intentionally, when they decide the work is ready.
- **Push to a draft PR early** — create the draft PR as soon as work begins, rather than keeping changes in a local branch. Push on every commit.
  - **In a new Conductor workspace, do this immediately** — as the first step of any task, make an initial commit on the workspace branch and open the draft PR right away (before the work is done), then keep pushing on every commit as you go. Don't wait until there's a finished change to show.
- **Never take a PR out of draft** — do not run `gh pr ready` or otherwise remove draft status, even after the work looks complete. Leave the PR in draft; the user promotes it manually and intentionally when they decide it's ready.
- **Do not rename branches after creating a PR** — deleting the old remote branch auto-closes the PR on GitHub, and the head ref cannot be changed after creation
- Use `docs/pull_request_template.md` for PR description structure
- **Remove the `Closes …` line when there's no ticket** — it's a template placeholder. Keep it (with a real issue link) only when the PR closes a tracked ticket; otherwise drop the line entirely rather than leaving the placeholder.
- **Lead with one plain-language sentence** — right after the review-depth tag, write a single sentence a non-dev could read that says what changes and, when you know it, *why it matters* (the user problem or business reason it solves). This is the one line that must land; everything below it is supporting detail. Write it like you're telling a colleague, not filing a report.
  - **Say the business reason when it's available, skip it when it isn't.** If the change fixes a pain point, unblocks a workflow, or was asked for, name that in plain terms ("facilitators couldn't tell which registrants had paid"). If no reason is known, don't invent one or pad — just describe the change plainly and move on.
- **Keep the whole thing short enough to read in one glance** — the lead sentence plus at most a handful of bullets. If it's longer than a short screenful, cut. A reviewer skims first; make the main point impossible to miss.
  - **Cut anything the diff already shows.** Only keep what a reader can't get from reading the code — the why, a non-obvious trade-off, a gotcha. Don't narrate the changes file by file.
  - **Bullets over prose, always.** Never write a paragraph where a bullet works. One idea per bullet; if a bullet needs a comma-spliced second clause, split it into two.
  - **Short, plain sentences.** One clause per bullet. Drop filler ("this PR", "in order to", "as well as"), hedging, and restating the ticket. Sentence fragments are fine when they're clear.
  - **Group with headers only when you truly need them** — a `##`/`###` header per section once the description genuinely spans more than one topic. Don't reach for headers on a small PR; they add scaffolding that makes a short description feel long.
- **Start the description with a review-depth tag** on its own single line, in the form `🤖 suggested review level: <N> <Name> <icon> <reason>`, followed by a blank line, then the rest of the description. The tag is the prefix, the level number, the level name, its icon, and a short reason — e.g. `🤖 suggested review level: 5 Inspect 🔬 substantive logic across 13 admin pages incl. filter behavior`. Always spell out the reason inline; never post the number/name/icon alone. The number is a 1–5 scale with three named levels (2 and 4 are unused in-betweens). The tag tells the reviewer how closely to look (depth of review, not how risky/good the change is):
  - **1 Skim 👀** — view-only: markup/copy/styling, no logic or data changes
  - **3 Read 📖** — light-logic: small, contained logic changes with low blast radius
  - **5 Inspect 🔬** — big change: substantive logic, migrations that rename or transform data (backfills), or wide-reaching changes that warrant careful review
- Include screenshots for UI changes
- **On every push**, update the PR title and content to reflect the current diff — preserve any existing images/screenshots in the description
- **On every push**, update AI instruction files if the diff adds, removes, or renames anything tracked in AGENTS.md — specifically: Stimulus controllers, services, model/controller concerns, mailers, rake tasks, and directory file counts
- **Inline-comment only to flag what matters to the reviewer** — do NOT comment on every push, and don't annotate routine or self-explanatory changes. Add a `gh api` line comment on the diff only when a reviewer genuinely needs something flagged: a non-obvious decision or trade-off, a risky/surprising change, a load-bearing assumption, or something easy to miss. When nothing rises to that bar, post no inline comments
- **Attribute every AI-authored GitHub comment** — `gh` posts as the authenticated user, so any comment you create (PR review comments, issue/PR comments, replies) MUST be prefixed to identify the AI agent that wrote it. Begin the comment body with `🤖 _From <agent>:_` (e.g. `🤖 _From Claude:_` or `🤖 _From Copilot:_`) followed by the content
- **Keep GitHub comments short and to the point** — one or two sentences, stating the key insight directly. Skip preamble, restating the code, and hedging; if a comment needs more than a few lines, it usually belongs in the PR description instead

## Ruby Version Manager

This project uses [mise](https://mise.jdx.dev/) to manage the Ruby version (read from [`.ruby-version`](.ruby-version) via the `idiomatic_version_file_enable_tools` setting in `mise.toml`).

Standard mise activation (`eval "$(mise activate <shell>)"` in your shell rc, per the [mise install guide](https://mise.jdx.dev/getting-started.html)) is sufficient for `bin/setup`, `bundle exec`, and Ruby commands run from a terminal. Scripts that run in contexts where the shell rc isn't sourced handle activation themselves:

- `bin/conductor-setup` activates mise explicitly (runs under `/bin/sh`, which doesn't source your interactive shell config)
- `ai/*` scripts source `ai/.ruby-env`

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

### On every completed task

**Close every message that reports work as done with the same two parts** — Recap, then
Unresolved with its count header — not just when the user asks for a recap or a PR is
submitted. A prose summary doesn't say whether anything still needs the user's attention;
the count header answers that in one line, before any detail. Mid-task progress notes are
exempt; this is for the message that says the work is finished.

## Response formatting

**Structure the answer; don't hand back a wall of text.** Long replies are for scanning
first and reading second.

- **Lead with the direct answer** when the user asked a question, then the detail.
- **Group under headers** (`##`/`###`) once a reply covers more than one topic.
- **Use titled bullets** — a bold lead-in naming the thing, then the explanation — rather
  than consecutive bare paragraphs.
- **Nest detail under the point it belongs to** instead of running it inline.
- Keep tables for genuinely tabular comparisons; keep prose short inside each bullet.

## Quick Commands

See `ai/` directory for executable scripts:

| Command | What it does |
|---|---|
| `ai/recap` | Session recap: accomplishments + unresolved items (see above) |
| `ai/review` | Code review: agent reviews the workspace diff, posts inline comments, and gives a Recap + Risks + Outstanding decisions summary (runs the `ai-review` skill) |
| `ai/test [args]` | Run RSpec, fast path: no Vite rebuild; runs only diff-related system specs (loud banner lists what it skipped) |
| `ai/test_extra [args]` | Full RSpec run: Vite test build + all system specs |
| `ai/lint` | Rubocop on all files |
| `ai/lint --fix` | Auto-fix lint issues |
| `ai/tw-sort` | Sort Tailwind class order (rustywind) on files changed vs main; `--all` for the whole tree, `--check` to verify without writing |
| `ai/server` | Start dev services (web + vite) |
| `ai/console` | Rails console |
| `ai/routes -g pattern` | Search Rails routes |
| `ai/migrate` | Run database migrations |
| `ai/seed` | Load the full dev sample dataset (`db:seed:dev`) into the workspace DB |
| `ai/security` | Security scan: Brakeman + bundler-audit (mirrors CI) |

> **"ai <name>" means the `ai/` script of that name** (e.g. "ai test" → `ai/test`, "ai security" → `ai/security`) — shell scripts in `ai/`, not slash-command skills. If a referenced `ai/<name>` script doesn't exist, ask what's intended rather than substituting a similarly named skill. Two are special — they print a trigger word, and the agent does the work directly rather than producing script output: (1) **"ai recap"** triggers the **Session recap** behavior above; never confuse it with the `/audit` design skill or the `ai/security` scan. (2) **"ai review"** (`ai/review`) triggers the **`ai-review` skill** — review the current workspace diff, post one inline comment per qualifying bug, then give a Recap + Risks + Outstanding decisions summary; it is not the `/audit` skill or the `/code-review` / `/review` skills.

> **Which test command to run.** Default to **`ai/test`** (fast path) for everything — bare "test"/"run tests" while iterating **and** ship flows like **"commit push"**, **"commit push pr"**, or **"commit push pr test"** (any combination of commit / push / PR, with or without "test"). The user watches the full suite on CI themselves, so **do not** run **`ai/test_extra`** (Vite build + all system specs) as part of a commit/push/PR flow. Run `ai/test_extra` **only** when the user explicitly asks for the full suite (e.g. "test_extra", "full tests", "run all system specs").
