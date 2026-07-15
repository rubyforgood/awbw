# AGENTS.md

Architecture reference for AI agents. For coding rules and conventions, see `CLAUDE.md` (single source of truth).

## Project Overview

AWBW Portal is a Rails 8.1 application (Ruby 4.0.1) for A Window Between Worlds — a platform where workshop leaders manage workshops, resources, community news, stories, and events.

## Tech Stack

- **Backend:** Rails 8.1, Ruby 4.0.1, MySQL (via Trilogy adapter)
- **Frontend:** Vite, Tailwind CSS v4, Stimulus, Turbo Rails
- **Auth:** Devise with JWT token support
- **Authorization:** ActionPolicy (app/policies/)
- **Rich text:** ActionText with Rhino editor (TipTap-based)
- **File uploads:** ActiveStorage with DigitalOcean Spaces
- **Background jobs:** SolidQueue
- **Caching:** SolidCache

## Setup

Full setup (bundle, npm, database create/migrate/seed):
```
bin/setup
```

If you just need frontend dependencies:
```
npm ci
```

## Architecture Overview

```
This codebase (Rails 8.1)
├── Main app (app/)              — Workshops, resources, stories, events, people, organizations
├── Frontend                     — Stimulus + Turbo + Tailwind CSS v4 (Vite bundler)
├── Background jobs              — SolidQueue
├── Caching                      — SolidCache
├── Auth                         — Devise (database + JWT)
├── Authorization                — ActionPolicy
└── Database                     — MySQL (Trilogy adapter)
```

## Directory Guide

### Business Logic

| Directory | Purpose | Count |
|---|---|---|
| `app/models/` | ActiveRecord models | ~80 files |
| `app/services/` | Service objects and POROs (e.g. `MoneyFormatter` for currency display) | ~30 files |
| `app/jobs/` | SolidQueue background jobs | 4 files |
| `app/models/concerns/` | Shared model modules | 16 concerns |

### Presentation

| Directory | Purpose | Count |
|---|---|---|
| `app/controllers/` | Rails controllers (admin/, events/) | ~77 files |
| `app/views/` | ERB templates | ~632 files |
| `app/decorators/` | Draper decorators for view logic | ~40 files |
| `app/policies/` | ActionPolicy authorization rules | ~55 files |
| `app/presenters/` | Presentation objects | 5 files |
| `app/helpers/` | View helpers | ~25 files |
| `app/mailers/` | ActionMailer classes | 5 files |
| `app/inputs/` | Custom SimpleForm inputs | 1 file |

### Frontend

| Directory | Purpose |
|---|---|
| `app/frontend/entrypoints/` | Vite entry points (application.js, application.css) |
| `app/frontend/javascript/controllers/` | Stimulus controllers (75) |
| `app/frontend/javascript/rhino/` | Rich text editor customizations (mentions, grid) |
| `app/frontend/stylesheets/` | Tailwind CSS and component styles |

### Configuration

| File/Directory | Purpose |
|---|---|
| `config/routes.rb` | All routes (single file) |
| `config/database.yml` | MySQL via Trilogy adapter |
| `config/initializers/` | ~30 initializer files |
| `.github/workflows/` | GitHub Actions CI |
| `Procfile.dev` | Dev services: `vite` + `web` |
| `ai/` | Shell script shortcuts for common dev tasks (see `ai/README.md`) |

## Key Models

### Core Content Models

| Model | Purpose |
|---|---|
| `User` | Devise authentication, SearchCop search, super_user admin flag |
| `Workshop` | Core content: rich text fields, categories, sectors, bookmarks, variations |
| `Event` | Events with registrations, featured/published states |
| `EventStaff` | Join model connecting `Person` to `Event` as staff (title, `expected_to_attend`); drives the "Meet the staff" roster and "My events" |
| `EventRegistrationChecklistCompletion` | Audited completion row for one manual onboarding step on an `EventRegistration` (`step` from `EventRegistration::CHECKLIST_STEPS`, `completed_by` User, `completed_at`); row-exists = done. Powers the event Onboarding tab's checkbox matrix |
| `RegistrationTicketCallout` | Call-outs shown on an event's registration ticket (title, subtitle, HTML description, `callout_type` action/reference, icon/colour, `payment_access_gated` — only shown once the registrant has `payment_access_granted?`, draggable `position`, `hidden` draft/opt-out, `display_from` drip date, and `has_many :resources` through `RegistrationTicketCalloutResource`); each links to its own public detail page. A nil `builtin_key` is an admin-authored callout; a set `builtin_key` is a built-in card materialized by `BuiltinCallouts` (hidden instead of deleted, restorable to default) |
| `RegistrationTicketCalloutResource` | Ordered join linking a `RegistrationTicketCallout` to the `Resource`s shown on its detail page |
| `Story` | Editorial content with facilitators, primary/gallery assets |
| `Resource` | Handouts, toolkits, templates with downloadable assets |
| `Person` | Organization affiliates with contacts, addresses, sectors |
| `OtherResponse` | A free-text "Other" typed on a form question, captured at submission time (registration, scholarship, bulk payment). Polymorphic `owner`: a **sector** "Other" is owned by the `Person` (promotable into a `Sector`, shown on their profile/edit chip); an **organization_type** "Other" is owned by the `Organization` (stored now, not promotable until `OrganizationType` is a model). `generic` questions aren't captured — that stays searchable in the form answers. `field_identifier` records the question; `kind` is derived. Curated at `/other_responses` (grouped by kind/question): `promote` (sectors only), `keep`, `dismiss`. `dismissed` hides the chip from the profile but stays in the review queue (still promotable later); only `promoted` leaves the queue. Admins deep-link there from a person's chip. |
| `Organization` | Groups with affiliations, addresses, logos via ActiveStorage |
| `Grant` | Donated funds (polymorphic `donor`: Organization or Person) with eligibility criteria, tasks, deadlines; parent of `Scholarship`. Scholarship totals cannot exceed the grant amount |
| `Scholarship` | Award to a `Person`; optionally drawn from a `Grant`, syncs to event registration `Allocation` |
| `ProfessionalLicense` | A license a `Person` holds (`number`, `kind`, `issuing_state`, `expires_on`); a null `number` is a placeholder. `find_or_create_for` keeps one license per (person, number) |
| `ContinuingEducationRegistration` | A registrant's CE for one event against one `ProfessionalLicense`; billable `allocatable` (`Registerable`) with stored `hours` + `cost_cents` (default from the event). Payment is computed (no stored status); the certificate is delivered via `certificate_sent_at` and gated by its own `certificate_available?` |
| `Report` | STI base class for MonthlyReport |
| `WorkshopLog` | Standalone model for workshop log submissions (attendance, form fields) |

### STI Models

- **Asset** (inheritance column: `type`): PrimaryAsset, GalleryAsset, RichTextAsset, DownloadableAsset, ThumbnailAsset
- **Report**: MonthlyReport

### Polymorphic Associations

- **Bookmarks** (`bookmarkable`): Workshop, Event, Resource, etc.
- **Grant donor** (`donor`): Organization, Person
- **Assets** (`owner`): Workshop, Story, Resource, Report, etc.
- **Comments** (`commentable`): User, Person, Organization, etc.
- **Categorizable/Sectorable** items: Workshop, Story, Resource, etc.
- **Forms** (`owner`): Resource, Report, etc.

### Model Concerns

| Concern | Purpose |
|---|---|
| `AgeGroupTaggable` | Splits AgeRange category taggings into primary/additional via `categorizable_items.is_primary` (Person, Organization) |
| `AhoyTrackable` | Event tracking integration |
| `AuthorCreditable` | Author attribution |
| `Featureable` | `featured`, `publicly_featured` scopes |
| `Mentioner` | ActionText @mention extraction and grouping |
| `NameFilterable` | Name-based filtering |
| `Publishable` | `published`, `publicly_visible` scopes |
| `PunctuationStrippable` | Strips punctuation from strings |
| `Registerable` | Shared payment (`allocations_sum`/`paid?`/`remaining_cost`/…) + certificate (`certificate_sent?`, `mark_certificate_sent!`) interface for `EventRegistration` and `ContinuingEducationRegistration`; includers supply `cost_cents` + their own `certificate_available?` |
| `RemoteSearchable` | AJAX remote search by column |
| `RichTextSearchable` | Full-text search on ActionText rich_text fields |
| `SectorsTaggable` | Enforces a single primary sector for sector-tagged owners |
| `TagFilterable` | Scope-based filtering by tag names |
| `Trendable` | Trending metrics tracking |
| `WindowsTypeFilterable` | Filter by WindowsType association |

## Controllers

### Namespaces

- **Root level** (~58 controllers): Workshops, stories, resources, events, people, organizations, registration ticket callouts, etc.
- **`admin/`**: HomeController, AnalyticsController, AhoyActivitiesController
- **`events/`**: Registrations sub-resource (create/destroy + slug-based show at `/registration/:slug`)
- **Devise overrides**: Registrations, Confirmations, Passwords

### Base Controller Pattern

```ruby
class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  verify_authorized                    # ActionPolicy enforcement

  # Common helpers:
  # authorize! @record               — check policy
  # authorized_scope(Model.all)      — filtered relation
  # @record.decorate                 — Draper decorator
end
```

### Controller Concerns

- `AhoyTracking` — Event tracking integration
- `Dedupable` — Data deduplication helpers
- `ExternallyRedirectable` — External URL redirection
- `TagAssignable` — Tag assignment helpers

## Services

### Analytics

- `Analytics::LifecycleBuffer` — Thread-safe event buffer for batch tracking
- `Analytics::EventBuilder` — Constructs analytics event payloads
- `Analytics::AhoyTracker` — Coordinates ahoy event tracking

### Business Logic

- `EventDashboard` — Aggregates per-event dashboard metrics (registrant/org/sector/state/county counts, scholarship totals, payment received/outstanding/total)
- `EventRevenueReport` — Cross-event revenue report grouped by calendar year (money in vs org subsidy vs net, projected CE, chart series) for the CEO revenue page
- `ScholarshipApplication` — Gathers one person's scholarship-application answers for an event by field across all their submissions, so answers surface whether captured on a dedicated scholarship form, an embedded registration section, or the registration submission itself (used by the scholarship edit page and the public submission view)
- `WorkshopSearchService` — Complex filtering, sorting, pagination with ActionPolicy
- `WorkshopFromIdeaService` — Converts WorkshopIdea to Workshop with asset migration
- `WorkshopVariationFromIdeaService` — Variation creation from ideas
- `TaggingSearchService` — Search and filter tagging data
- `PersonFromUserService` — Create Person from User account
- `BulkInviteService` — Bulk send welcome instructions and reset created_at for users
- `FormBuilderService` — Builds configurable forms from composable sections with per-field visibility
- `ModelDeduper` — Deduplication logic
- `RichTextMigrator` — Rich text migration utility
- `DisplayImagePresenter` — Image display logic
- `ScholarshipsGrouping` (presenter) — Groups scholarships into the index's funder → grant → recipient hierarchy; grant-free awards collect under a trailing "Unfunded" group
- `AllocationLedgerLabel` (presenter) — Shared payment-method/label + check-number labelling for an allocation, used by the invoice and receipt ledgers so they can't drift

### Event Registrations

- `EventRegistrationServices::ProcessConfirmation` — Registration confirmation flow
- `EventRegistrationServices::PublicRegistration` — Public registration handling
- `EventRegistrationReadiness` — Computes a registration's lifecycle `status` (`:not_ready` → `:ready` → `:certificate_due` → `:completed`) from a pre-event "event ready" checklist, a post-event "completion work" checklist (attendance, scholarship tasks), and certificate delivery, returning the specific outstanding reasons. Reads payment/certificate state via `Registerable` (`paid_in_full?`, `certificate_sent?`) on both the registration and its `continuing_education_registrations`. Drives the registrants roster's single far-right Status badge column (with a short reason under "Not ready" and a cert-type note under "Certificate pending") and its matching filter
- `ReminderRecipientFilter` — Decides which event registrations stay checked on the bulk reminder page given the admin's filters (matches in memory, returns matching ids)
- `BuiltinCalloutCards` — Renders the live, per-registration ticket callout cards (payment, certificate, scholarship, CE hours, videoconference), overlaying dynamic status (badge, colour, visibility guard, destination) on each materialized built-in row via `#card_for`. Rendered through the same `_callout_card` partial as `RegistrationTicketCallout`s. Skips any card an event has materialized (see `BuiltinCallouts`) so the two paths never double-render, and `#cards` serves as the fallback for events not yet seeded; `.editor_cards` builds the editor's preview cards. Art supplies, Handouts, and FAQ are pure content cards with no builder here — they render from their row. Public show pages live under `app/views/events/callouts/` (`Events::CalloutsController`, slug-authorized)
- `BuiltinCallouts` — Owns the built-in callout definitions and materializes them into `RegistrationTicketCallout` rows in canonical ticket order: `seed` persists (on create, and lazily on edit so older events heal with no backfill), `build` makes the same rows in memory for the new-event form (with `builtin_key` round-tripped through nested attributes), `reset`/`customized?` back the "Restore default" control. All eight seed **hidden** by default — admins publish the ones they want; there's no config-based auto-publish. Built-ins are edited in the **same** callout-fields row as custom callouts (pre-filled title/subtitle/colour/icon/callout-page-text/resources; hidden instead of deleted; "Restore default" shown only when `.customized?`). "Content" cards (Art supplies, Handouts, FAQ) render their own copy/resources on the generic callout page; "behavioral" cards render live status through `BuiltinCalloutCards#card_for`, which overlays the app's badge/visibility/destination on the row's editable presentation. Behavioral pages show the row's callout-page-text as an intro (`@builtin_intro`) and any linked resources below it. Videoconference drips a week before start via `display_from`. CE hours and Art supplies are edited like every other built-in — their title/text live entirely on the row (the legacy `event_details*`/`ce_hours_details*` event columns were dropped); the CE hours-offered/cost config still edits the event inline via `event_f` (`ce_config?`). The registrant CE page reads the row's title/description. Built-ins always seed and also materialize lazily on `edit`, so the editor shows the full set; the editor shows "Restore default" (or a static "Matches default") per row via `.customized?`. The visibility control is a `published` toggle (inverse of `hidden`)
- `CalloutContent` — Parses admin-authored callout HTML into ordered segments so **every** callout content page renders the same way: plain rich text, with each standard `<details><summary>…</summary>…</details>` disclosure (the markup any HTML generator/LLM produces; `<toggle>` and a `title` attribute are accepted aliases; `<details open>` starts expanded) rebuilt into a styled collapsible card. `<details>`/`<summary>` are also on the `form_label_html` allowlist (`FORM_LABEL_TAGS`, plus the `open` attribute), so a disclosure is never stripped on save — the parser only upgrades its styling. Rendered through the shared `app/views/events/callouts/_rich_content.html.erb` partial (which wraps each disclosure in `_toggle.html.erb`), used by the art-supplies ("Art supplies & what to bring", a content callout on the generic page), CE hours, custom-callout, behavioural-card-intro, and FAQ pages. The FAQ page renders the editable `faq` callout `description` (each question a `<details>`), falling back to `BuiltinCallouts.faq_html` when the card isn't materialized. Content with no disclosure renders unchanged

### Affiliations

- `AffiliationServices::CreateFromRegistration` — On registration / org linking, creates a "job affiliation" with the typed title (when present) plus a standing "Facilitator" affiliation, in one transaction. Skips the facilitator one only when the person already has an active-or-pending affiliation titled exactly "Facilitator" with that org (a current one or one dated to a future training); an ended facilitator affiliation gets a fresh second one. Dedupe is by title + org + dates, so a job title like "Lead Facilitator" still gets its own Facilitator affiliation. Accepts an optional `organization_address:` and sets it on every affiliation it creates (the registrant's typed agency address, upserted onto the org); when an affiliation already exists and is skipped, it backfills that address onto the existing one only if it has none (an admin-set address is never overwritten)

### Sectors

- `SectorTagging` — `.apply(person:, organizations:, primary_ids:, additional_ids:)` tags a person's sectors (primary + additional) and mirrors them onto the given organizations as additional-only (orgs aggregate members' sectors and have no primary). Shared by registration (person's selections onto the org they registered with) and "Other" sector-response promotion (additional only). Promotion passes `OtherResponse#registration_organizations`, which derives the org from the response's `source_form_answer` → submission → the person's registration for that event — so it tags exactly the org registration would have, without storing one on the response

### Other responses

- `OtherResponses::CaptureFromSubmission` — Materializes a form submission's **person-owned** "Other" answers (sectors) as `OtherResponse` records; org-type "Other" is captured separately in `PublicRegistration#sync_agency_type` (owned by the org). Uses `OtherOption.texts`, which keys strictly on the `Other:` prefix, so named specify options and the CE `Yes: N` box are ignored; de-dupes per owner + question. Shared by the registration, scholarship, and bulk-payment submission paths

### Organizations

- `OrganizationServices::UpsertAddress` — Find-or-create an organization's "work" address from a registrant's submitted agency fields (street/city/state/zip/country). Updates the matching city/state address in place, else adds a new one; never demotes the org's existing primary (a registrant's address becomes primary only when the org has none yet). Returns nil when no city is given. Shared by `PublicRegistration` and the admin org-linking actions so both build the org address identically before linking the affiliation to it

### Notifications

- `NotificationServices::CreateNotification` — Notification creation
- `NotificationServices::PersistDeliveredEmail` — Email delivery tracking

### User Management

- `UserServices::ProcessEmailChange` — Email change processing
- `UserServices::ProcessEmailManualConfirm` — Manual email confirmation

## Decorators (Draper)

All inherit from `ApplicationDecorator` which provides:
- `delegate_all` for transparent delegation
- `display_image` — selects primary/gallery/downloadable asset intelligently
- `link_target` — polymorphic path generation

Key decorators: WorkshopDecorator, StoryDecorator, ResourceDecorator, PersonDecorator, OrganizationDecorator, UserDecorator, EventDecorator, ReportDecorator, GrantDecorator, ScholarshipDecorator (derives the scholarship index's program/location/training/status columns).

## Policies (ActionPolicy)

### Base Pattern

```ruby
class ApplicationPolicy < ActionPolicy::Base
  authorize :user, optional: true, allow_nil: true
  default_rule :manage?
  alias_rule :index?, :show?, :new?, :create?, :edit?, :update?, to: :manage?

  def manage? = admin?
  def destroy? = record.persisted? && manage?

  private
  def admin? = user&.super_user?
  def authenticated? = user.present?
  def owner? = record.created_by_id == user.id || record.user_id == user.id
end
```

### Relation Scoping

```ruby
relation_scope do |relation|
  next relation if admin?
  authenticated? ? relation.published : relation.publicly_visible
end
```

## Mailers

- `ApplicationMailer` — Base, from: `ENV["REPLY_TO_EMAIL"]`
- `DeviseMailer` — Custom Devise emails
- `EventMailer` — Event registration confirmations
- `NotificationMailer` — Notification delivery
- `ContactUsMailer` — Contact form submissions
- All use premailer-rails for inline CSS
- **Previews** live in `test/mailers/previews/` (viewable at `/rails/mailers/` in development)

## Frontend

### Stimulus Controllers

- `address_select` — Compact numbered picker linking an affiliation to an org address
- `affiliation_dates` — Recalculate affiliation date ranges
- `anchor_highlight` — Highlight anchored elements
- `asset_picker` — Asset selection UI
- `autosave` — Auto-save form state
- `carousel` — Swiper-based carousels
- `ce_license_picker` — Fill the CE license type/number/state/expiry fields from the picked license (or clear them for a new one)
- `cocoon` — Nested form handling (cocoon gem)
- `collection` — Filter form auto-submit with debounce
- `column_toggle` — Toggle table column visibility
- `confirm_email` — Email confirmation UI
- `dirty_form` — Unsaved changes detection
- `dismiss` — Dismissable elements
- `dropdown` — Dropdown menus with keyboard/click-outside handling
- `edit_toggle` — Inline view/edit toggle for the comments and communications boxes (configurable view/edit CSS classes)
- `event_staff_bio` — Loads a selected person's read-only profile bio (with edit link) alongside the editable event-specific bio on the staff form
- `file_preview` — File upload preview
- `grant_details` — Swaps a grant's eligibility criteria + tasks when the grant picker changes
- `grant_select` — Tom Select grant picker showing each grant's remaining-of-total funds
- `inactive_toggle` — Gray out expired affiliations
- `optimistic_bookmark` — Instant bookmark UI feedback
- `org_toggle` — Organization toggle UI
- `paginated_fields` — Client-side pagination of nested fields
- `password_toggle` — Show/hide password fields
- `prefetch_lazy` — Prefetch lazy-loaded content
- `primary_tag` — Shared single-primary star for the sector and age-range cocoon chip editors (clears other stars, highlights via configurable classes, no reorder)
- `print_options` — Print options toggle for analytics
- `reminder_preview` — Live-preview a custom message in the reminder email as the admin types it on the bulk-reminder page
- `remote_select` — AJAX-powered select dropdown
- `reveal_section` — Expand a collapsible section and scroll to it when loaded via matching URL hash
- `rhino_source` — Rich text editor integration
- `scholarship_preview` — Live-preview the scholarship's allocated amount as the edit form changes
- `scroll_to_top` — Scrolls the window to the top on connect (used by the duplicate-person warning so it comes into view on create)
- `searchable_checkbox` — TomSelect checkbox-style multi-select
- `searchable_select` — Tom Select autocomplete
- `share_url` — URL sharing/copying
- `sortable` — Drag-drop sorting (SortableJS); persists order via a per-row PUT (used by categories index and the registration ticket callouts editor)
- `submit_once` — Disables a form's submit button after submit to block duplicate submissions; re-enables on Back/bfcache/Turbo restore
- `tabs` — Tab panel navigation
- `tag_link_loading` — Loading state for tag links
- `tags_combination_highlight` — Highlight tags matching selected filters
- `tags_sync_list_heights` — Sync tag list column heights
- `timeframe` — Date range filtering
- `toggle_lock` — Lock/unlock toggle UI
- `toggle_user_icon` — User icon visibility toggle
- `us_map_chart` — US states choropleth map (event Background states breakdown)

### JS Dependencies

| Library | Purpose |
|---|---|
| TipTap + ProseMirror | Rich text editor (Rhino) |
| Tom Select | Advanced select components |
| Chart.js + Chartkick | Analytics charts |
| chartjs-chart-geo + us-atlas | US choropleth map (states breakdown) |
| Swiper | Image carousels |
| SortableJS | Drag-and-drop sorting |
| Tippy.js | Tooltips |
| Font Awesome 7 | Icons |

### Tailwind Theme

Custom colors defined in `app/frontend/stylesheets/application.tailwind.css`:
- `--color-primary: #063b8d` (dark blue)
- Standard semantic colors: secondary, danger, warning, info, success

## Testing

### Structure

| Directory | Count | Purpose |
|---|---|---|
| `spec/models/` | ~71 | Model unit tests |
| `spec/views/` | ~77 | View template tests |
| `spec/requests/` | ~91 | HTTP request/integration tests |
| `spec/system/` | ~20 | End-to-end browser tests (Capybara) |
| `spec/routing/` | ~15 | Route definition tests |
| `spec/policies/` | ~15 | Authorization policy tests |
| `spec/decorators/` | ~15 | Decorator tests |
| `spec/services/` | ~25 | Service object tests |
| `spec/mailers/` | ~5 | Mailer tests |
| `spec/helpers/` | ~5 | Helper tests |
| `spec/factories/` | ~67 | FactoryBot factory definitions |

### Configuration

- **rails_helper.rb**: Loads RSpec Rails, FactoryBot, Shoulda Matchers, ActionPolicy, Devise test helpers, ActiveStorage validation matchers. Transactional fixtures enabled. ActiveJob uses `:test` adapter.
- **spec_helper.rb**: Random test ordering, profile of 10 slowest examples. SimpleCov (branch coverage, minimum 20%) runs only when `COVERAGE=true` (set by the coverage-badge workflow on `main`), not on every run. Under `CI=true`, each parallel process writes its own JSON results file to `tmp/rspec_results/` keyed on `TEST_ENV_NUMBER`.

### Running in parallel

The suite runs across multiple processes via [`parallel_tests`](https://github.com/grosser/parallel_tests), each with its own database (`awbw_test`, `awbw_test2`, … — the `TEST_ENV_NUMBER` suffix is appended in `config/database.yml`):

```
bundle exec rake parallel:create parallel:load_schema   # one-time per schema change
bundle exec parallel_rspec spec/                        # run the whole suite in parallel
```

### Support Files

- `spec/support/capybara.rb` — Selenium Chrome headless driver
- `spec/support/devise.rb` — Devise integration for request/view/system specs
- `spec/support/eventually_matcher.rb` — Custom async assertion matcher
- `spec/support/shared_examples/featureable.rb` — Shared tests for featured content
- `spec/support/shared_examples/mentioner.rb` — Shared tests for @mention functionality
- `spec/support/system_helpers/asset_upload_helpers.rb` — Upload/delete helpers for system tests

### Factory Traits

Common factory traits across models:
- `:featured`, `:published`, `:unpublished`
- `:publicly_visible`, `:publicly_featured`
- `:admin` (User with super_user=true)
- `:with_primary_asset`, `:with_gallery_assets`

## Linting & Security

```
bundle exec rubocop        # lint
bundle exec rubocop -a     # auto-fix
bundle exec brakeman       # security scan
bundle exec bundle-audit check --update
```

## CI Pipeline (GitHub Actions)

### ci.yml

1. **scan_ruby**: Brakeman security analysis + bundler-audit
2. **build-and-test**: MySQL 8.0 service, Ruby + Node 22 setup, `npm ci`, `parallel:create parallel:load_schema`, then `parallel_rspec spec/` across 4 processes (`PARALLEL_TEST_PROCESSORS=4`)

### rubocop.yml

RuboCop linting on PRs and pushes to main.

## Key Library Usage

| Need | Library |
|---|---|
| Authentication | Devise (database + confirmable + lockable + trackable) |
| Authorization | ActionPolicy with relation scoping |
| Search | SearchCop (multi-field, rich text joins) |
| Decorators | Draper (with ActionPolicy integration via initializer) |
| Forms | SimpleForm + Cocoon (nested forms) |
| Pagination | WillPaginate with TailwindPaginationRenderer |
| Rich text | ActionText + Rhino editor (TipTap-based) |
| File uploads | ActiveStorage (DigitalOcean Spaces) + legacy Paperclip |
| Feature flags | FeatureFlipper |
| Analytics | Ahoy (events + visits), Chartkick, Groupdate, Blazer |
| Geocoding | Geocoder + MaxMind GeoIP2 |
| Email styling | Premailer-rails (inline CSS) |
| Positioning | Positioning gem for ordered records |

## Rake Tasks

Located in `lib/tasks/` (8 files):
- `dev.rake` — Development database seeding from XML/CSV
- `rhino_migrator.rake` — Rich text editor migration
- `attachment_report.rake` — Attachment reporting
- `migrate_internal_id_to_filemaker_code.rake` — FileMaker code migration
- `convert_age_ranges.rake` — Age range data conversion
- `legacy_user_permissions_to_comments.rake` — Migrate legacy user permissions into comments
- `migrate_sectors.rake` — Sector data migration
- `migrate_workshop_logs.rake` — Workshop log migration
