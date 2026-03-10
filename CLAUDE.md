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

## HTML/ERB Formatting

### Tag Attributes
- **Closing `>` on same line as last attribute** — do not put `>` on its own line
- When attributes span multiple lines, keep the closing `>` with the last attribute
- Good: `<div class="..." id="...">` or `<div class="...\n     id="...">`
- Bad: `<div class="...\n     id="..."\n  >`

## AI Instruction Files

When the user says "AI files" or "AI instructions", these are the files:

| File | Purpose |
|---|---|
| `CLAUDE.md` | Primary rules for Claude Code (this file) |
| `AGENTS.md` | Architecture reference (models, controllers, services) |
| `.github/copilot-instructions.md` | Rules for GitHub Copilot (keep in sync with CLAUDE.md) |
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
| Add/remove model, concern, service, or gem | AGENTS.md, `.github/copilot-instructions.md` |
| Code style rules | `.github/copilot-instructions.md` (keep in sync) |

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
- **Strongly prefer Stimulus** for JavaScript behavior — do not write raw/inline JS or jQuery
- **Always use Tailwind CSS** utility classes for styling — do not write custom CSS unless absolutely necessary
- Prefer Turbo for navigation and form submissions before reaching for Stimulus
- Controller naming: `[name]_controller.js`
- Keep controllers focused and small

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

- Name migration files using **UTC timestamps** (e.g., `20260228143000`), not sequential numbers (e.g., `20260228000007`)
- Multiple branches adding migrations on the same date will collide if they use sequential numbering

## Git

- Default branch is `main`
- Commit messages should explain why, not what
- CI runs via GitHub Actions (`.github/workflows/`)
- **When rebasing onto main**, review incoming changes for their intent and flag any oversights — missing tests, incomplete migrations, broken assumptions, or conflicts between the two branches. Check both directions: schema/model changes on either branch that affect views, partials, or layouts on the other (e.g., main redesigned a table's CSS but your branch adds new columns to it, or vice versa)

## PRs

- After completing work, **create a pull request** using `gh pr create`
- Once the PR is created, **prepend the PR number to the branch name** (e.g., rename `maebeale/fix-login` to `maebeale/1234-fix-login`) using `git branch -m` and `git push origin -u` with the new name, then delete the old remote branch
- Use `docs/pull_request_template.md` for PR description structure
- Use bullet points, not paragraphs, when filling out each section
- Description must explain why the change was made, not just what
- Include screenshots for UI changes
- **On every push**, update the PR title and content to reflect the current diff

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
