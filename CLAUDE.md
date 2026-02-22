# CLAUDE.md

## Project Overview

This is a Ruby on Rails 8.1 application (Ruby 4.0.1) — the Portal for A Window Between Worlds (AWBW). It manages workshops, resources, community news, stories, and events for workshop leaders.

## Tech Stack

- **Backend:** Rails 8.1, Ruby 4.0.1, MySQL (via Trilogy adapter)
- **Frontend:** Vite, Tailwind CSS v4, Stimulus, Turbo Rails
- **Auth:** Devise with JWT token support
- **Authorization:** ActionPolicy (app/policies/)
- **File uploads:** ActiveStorage with DigitalOcean Spaces
- **Background jobs:** SolidQueue
- **Caching:** SolidCache

## Code Style

- Follow RuboCop with rubocop-rails-omakase, rubocop-rails, and rubocop-performance
- Use modern Ruby syntax
- Prefer early returns and guard clauses
- Avoid unnecessary and/or complex conditionals
- Prefer enums and scopes over magic strings
- Use safe navigation (`&.`) where appropriate
- Use `presence` over blank checks
- Use `Arel.sql` for raw SQL in order clauses
- Avoid `update_all` unless explicitly intended
- Prefer service objects under app/services/
- Prefer POROs over concerns when possible
- Use `after_commit` instead of `after_save` for side effects

## Key Directories

- `app/services/` — Business logic service objects
- `app/decorators/` — Draper decorators for view presentation
- `app/policies/` — ActionPolicy authorization rules
- `app/presenters/` — Presentation objects
- `app/frontend/` — Vite/JS components (Stimulus controllers, etc.)
- `frontend/` — Additional frontend assets

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
