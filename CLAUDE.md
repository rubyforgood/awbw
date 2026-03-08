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
- **Use Stimulus targets and data attributes** to reference DOM elements — avoid `this.element.querySelector` and direct DOM queries. Declare `static targets = [...]` and use `data-[controller]-target` attributes in views.
- **Use Stimulus shorthand action descriptors and shorthand pairs** — omit the event when it's the default for that element (e.g., `input` for `<input>`/`<textarea>`, `click` for `<button>`/`<a>`, `submit` for `<form>`). Write `controller#action` not `input->controller#action` on an input element. Only specify the event when using a non-default (e.g., `change->controller#action` on an input). See [Stimulus Actions](https://stimulus.hotwired.dev/reference/actions#event-shorthand).

## Migrations

- Name migration files using **UTC timestamps** (e.g., `20260228143000`), not sequential numbers (e.g., `20260228000007`)
- Multiple branches adding migrations on the same date will collide if they use sequential numbering

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
