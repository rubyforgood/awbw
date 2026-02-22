# AGENTS.md — AWBW Portal

Architecture reference for AI agents working on the AWBW Portal codebase. For coding rules and quick commands, see `CLAUDE.md`.

## Project Summary

AWBW Portal is a Rails 8.1 application (Ruby 4.0.1) for A Window Between Worlds — a platform where workshop leaders manage workshops, resources, community news, stories, and events. It uses MySQL, Vite, Tailwind CSS v4, and the Hotwire stack (Stimulus + Turbo).

## Architecture Overview

```
AWBW Portal (Rails 8.1)
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
| `app/models/` | ActiveRecord models | ~78 files |
| `app/services/` | Service objects for complex logic | ~15 files |
| `app/jobs/` | SolidQueue background jobs | 2 files |
| `app/models/concerns/` | Shared model modules | ~11 concerns |

### Presentation

| Directory | Purpose | Count |
|---|---|---|
| `app/controllers/` | Rails controllers (admin/, api/v1/, events/) | ~66 files |
| `app/views/` | ERB templates | ~434 files |
| `app/decorators/` | Draper decorators for view logic | ~36 files |
| `app/policies/` | ActionPolicy authorization rules | ~43 files |
| `app/presenters/` | Presentation objects | 1 file |
| `app/helpers/` | View helpers | ~19 files |
| `app/mailers/` | ActionMailer classes | 6 files |
| `app/inputs/` | Custom SimpleForm inputs | 1 file |

### Frontend

| Directory | Purpose |
|---|---|
| `app/frontend/entrypoints/` | Vite entry points (application.js, application.css) |
| `app/frontend/javascript/controllers/` | Stimulus controllers (~32) |
| `app/frontend/javascript/rhino/` | Rich text editor customizations (mentions, grid) |
| `app/frontend/stylesheets/` | Tailwind CSS and component styles |

### Configuration

| File/Directory | Purpose |
|---|---|
| `config/routes.rb` | All routes (single file) |
| `config/database.yml` | MySQL via Trilogy adapter |
| `config/initializers/` | ~32 initializer files |
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
| `Story` | Editorial content with facilitators, primary/gallery assets |
| `Resource` | Handouts, toolkits, templates with downloadable assets |
| `Person` | Organization affiliates with contacts, addresses, sectors |
| `Organization` | Groups with affiliations, addresses, logos via ActiveStorage |
| `Report` | STI base class for MonthlyReport and WorkshopLog |

### STI Models

- **Asset** (inheritance column: `type`): PrimaryAsset, GalleryAsset, RichTextAsset, DownloadableAsset, ThumbnailAsset
- **Report**: MonthlyReport, WorkshopLog

### Polymorphic Associations

- **Bookmarks** (`bookmarkable`): Workshop, Event, Resource, etc.
- **Assets** (`owner`): Workshop, Story, Resource, Report, etc.
- **Comments** (`commentable`): User, Person, Organization, etc.
- **Categorizable/Sectorable** items: Workshop, Story, Resource, etc.
- **Forms** (`owner`): Resource, Report, etc.

### Model Concerns

| Concern | Purpose |
|---|---|
| `Featureable` | `featured`, `publicly_featured` scopes |
| `Publishable` | `published`, `publicly_visible` scopes |
| `TagFilterable` | Scope-based filtering by tag names |
| `Trendable` | Trending metrics tracking |
| `WindowsTypeFilterable` | Filter by WindowsType association |
| `RemoteSearchable` | AJAX remote search by column |
| `RichTextSearchable` | Full-text search on ActionText rich_text fields |
| `Mentioner` | ActionText @mention extraction and grouping |
| `NameFilterable` | Name-based filtering |
| `PunctuationStrippable` | Strips punctuation from strings |
| `AhoyTrackable` | Event tracking integration |

## Controllers

### Namespaces

- **Root level** (~48 controllers): Workshops, stories, resources, events, people, organizations, etc.
- **`admin/`**: HomeController, AnalyticsController, AhoyActivitiesController
- **`api/v1/`**: ApiController base, Authentications, Workshops, Quotes, Resources
- **`events/`**: Registrations sub-resource
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

## Services

### Analytics

- `Analytics::LifecycleBuffer` — Thread-safe event buffer for batch tracking
- `Analytics::EventBuilder` — Constructs analytics event payloads
- `Analytics::AhoyTracker` — Coordinates ahoy event tracking

### Business Logic

- `WorkshopSearchService` — Complex filtering, sorting, pagination with ActionPolicy
- `WorkshopFromIdeaService` — Converts WorkshopIdea to Workshop with asset migration
- `WorkshopVariationFromIdeaService` — Variation creation from ideas
- `TaggingSearchService` — Search and filter tagging data
- `PersonFromUserService` — Create Person from User account
- `AuthenticationToken` — JWT token generation for API
- `ModelDeduper` — Deduplication logic
- `NotificationServices::CreateNotification` — Notification creation
- `NotificationServices::PersistDeliveredEmail` — Email delivery tracking

## Decorators (Draper)

All inherit from `ApplicationDecorator` which provides:
- `delegate_all` for transparent delegation
- `display_image` — selects primary/gallery/downloadable asset intelligently
- `link_target` — polymorphic path generation

Key decorators: WorkshopDecorator, StoryDecorator, ResourceDecorator, PersonDecorator, OrganizationDecorator, UserDecorator, EventDecorator, ReportDecorator.

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

- `ApplicationMailer` — Base, from: `ENV["REPLY_TO_EMAIL"]` (programs@awbw.org)
- `DeviseMailer` — Custom Devise emails
- `EventMailer` — Event registration confirmations
- `NotificationMailer` — Notification delivery
- `ContactUsMailer` — Contact form submissions
- All use premailer-rails for inline CSS
- **Previews** live in `test/mailers/previews/` (viewable at `/rails/mailers/` in development)

## Frontend

### Stimulus Controllers (32)

Key controllers:
- `asset_picker` — Asset selection UI
- `autosave` — Auto-save form state
- `carousel` — Swiper-based carousels
- `cocoon` — Nested form handling (cocoon gem)
- `dirty_form` — Unsaved changes detection
- `dropdown` — Dropdown menus with keyboard/click-outside handling
- `file_preview` — File upload preview
- `optimistic_bookmark` — Instant bookmark UI feedback
- `remote_select` — AJAX-powered select dropdown
- `searchable_select` — Tom Select autocomplete
- `sortable` — Drag-drop sorting (SortableJS)
- `tabs` — Tab panel navigation
- `rhino_source` — Rich text editor integration

### JS Dependencies

| Library | Purpose |
|---|---|
| TipTap + ProseMirror | Rich text editor (Rhino) |
| Tom Select | Advanced select components |
| Chart.js + Chartkick | Analytics charts |
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
| `spec/models/` | ~54 | Model unit tests |
| `spec/views/` | ~72 | View template tests |
| `spec/requests/` | ~41 | HTTP request/integration tests |
| `spec/system/` | ~30 | End-to-end browser tests (Capybara) |
| `spec/routing/` | ~13 | Route definition tests |
| `spec/policies/` | ~9 | Authorization policy tests |
| `spec/decorators/` | ~8 | Decorator tests |
| `spec/services/` | ~4 | Service object tests |
| `spec/mailers/` | ~3 | Mailer tests |
| `spec/helpers/` | ~2 | Helper tests |
| `spec/factories/` | ~52 | FactoryBot factory definitions |

### Configuration

- **rails_helper.rb**: Loads RSpec Rails, FactoryBot, Shoulda Matchers, ActionPolicy, Devise test helpers, ActiveStorage validation matchers. Transactional fixtures enabled. ActiveJob uses `:test` adapter.
- **spec_helper.rb**: SimpleCov with branch coverage (minimum 20%), random test ordering, profile of 10 slowest examples.

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

## CI Pipeline (GitHub Actions)

### ci.yml

1. **scan_ruby**: Brakeman security analysis + bundler-audit
2. **build-and-test**: MySQL 8.0 service, Ruby + Node 22 setup, `npm ci`, schema load, `bundle exec rspec`

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
| API | JWT tokens, Apipie docs, Rack CORS |

## Rake Tasks

Located in `lib/tasks/` (~17 files). Notable:
- `dev.rake` — Development database seeding from XML/CSV
- `paperclip_to_active_storage.rake` — File upload migration
- `rhino_migrator.rake` — Rich text editor migration
- `tag_deduping.rake` — Tag deduplication
- `bulk_invite.rake` — Bulk user invitations
