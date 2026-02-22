# CLAUDE.md

## Architecture Reference

For detailed architecture, models, controllers, services, and testing structure, read `AGENTS.md`.

## Project Overview

This is a Ruby on Rails 8.1 application (Ruby 4.0.1) — the Portal for A Window Between Worlds (AWBW). It manages workshops, resources, community news, stories, and events for workshop leaders.

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

## Code Style

- Follow RuboCop with rubocop-rails-omakase
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

## Related Files

When changing a model or controller, check whether these related files need updates:

| If you change... | Also check... |
|---|---|
| Model | Decorator, policy, factory, model spec |
| Controller | Policy, request spec, routing spec, views |
| View | System spec, Stimulus controller (if interactive) |
| Service | Service spec |
| Decorator | Decorator spec |
| Add/remove model, concern, service, or gem | AGENTS.md, `.github/copilot-instructions.md` |

## Key Directories

- `app/services/` — Business logic service objects
- `app/decorators/` — Draper decorators for view presentation
- `app/policies/` — ActionPolicy authorization rules
- `app/presenters/` — Presentation objects
- `app/frontend/` — Vite/JS components (Stimulus controllers, etc.)

## Testing

- **Framework:** RSpec (`bundle exec rspec`)
- **Factories:** FactoryBot (spec/factories/)
- **Matchers:** Shoulda Matchers
- **System tests:** Capybara with Selenium
- **Coverage:** SimpleCov

Run all tests:
```
bundle exec rspec
```

Run a single test file:
```
bundle exec rspec spec/models/some_model_spec.rb
```

## Linting

```
bundle exec rubocop
```

Auto-fix:
```
bundle exec rubocop -a
```

## Security Scanning

```
bundle exec brakeman
bundle exec bundle-audit check --update
```

## JavaScript

- ES6+ syntax, ESM imports/exports
- Prefer Stimulus + Turbo for new interactive features
- Controller naming: `[name]_controller.js`
- Keep controllers focused and small
- Use Tailwind CSS v4 utility classes

## Git

- Default branch is `main`
- Commit messages should explain why, not what
- CI runs via GitHub Actions (`.github/workflows/`)

## PRs

- Use `docs/pull_request_template.md` for PR description structure
- Use bullet points, not paragraphs, when filling out each section
- Description must explain why the change was made, not just what
- Include screenshots for UI changes

## Quick Commands

See `ai/` directory for executable scripts:

| Command | What it does |
|---|---|
| `ai/test [args]` | Run RSpec |
| `ai/lint` | Rubocop on all files |
| `ai/lint --fix` | Auto-fix lint issues |
| `ai/server` | Start dev services (web + vite) |
| `ai/console` | Rails console |
| `ai/routes -g pattern` | Search Rails routes |
| `ai/db-migrate` | Run database migrations |
