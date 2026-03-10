# Copilot Instructions

Read `AGENTS.md` for architecture reference (models, controllers, services, testing structure).

# Code Style

- Use modern Ruby syntax
- Prefer early returns and guard clauses
- Avoid unnecessary and/or complex conditionals
- Prefer constants and scopes over magic strings
- Use safe navigation (`&.`) where appropriate
- Use `presence` over blank checks
- Use `Arel.sql` for raw SQL in order clauses
- Avoid `update_all` unless explicitly intended
- Prefer service objects under app/services
- Prefer POROs over concerns when possible
- Use `after_commit` instead of `after_save` for side effects

# RuboCop (rubocop-rails-omakase)

This project uses rubocop-rails-omakase. All code MUST follow these rules:

## Strings
- Always use double quotes: `"foo"` not `'foo'`

## Spacing
- Spaces inside array brackets: `[ a, b, c ]` not `[a, b, c]` (empty arrays: `[]`)
- Spaces inside hash braces: `{ a: 1, b: 2 }` not `{a: 1}` (empty hashes: `{}`)
- Spaces inside block braces: `foo { bar }` not `foo {bar}` (empty blocks: `foo { }`)
- No spaces inside parens: `foo(bar)` not `foo( bar )`
- No spaces inside reference brackets: `hash[:key]` not `hash[ :key ]`
- Space before block braces: `foo { }` not `foo{ }`

## Commas
- No trailing commas in arrays, hashes, or method arguments

## Indentation
- 2-space indentation, no tabs
- Consistent indentation at normal level — do NOT indent methods under `private`/`protected`
- Align `end` with the variable in assignments
- Align `when` with `end`, not with `case`

## Whitespace
- No trailing whitespace on any line
- No trailing blank lines at end of file
- No empty lines inside class, module, method, or block bodies

## Syntax
- Use `%w[]` and `%i[]` with square bracket delimiters (not parens)
- Use modern hash syntax: `{ key: value }` not `{ :key => value }`
- No redundant returns — omit `return` on last expression
- Use `flat_map` instead of `.map { }.flatten`
- No redundant `.to_s` inside string interpolation
- Use `Foo.method` not `Foo::method` for method calls
- No parentheses around conditions: `if foo` not `if (foo)`
- No semicolons to separate statements

# HTML/ERB Formatting

## Tag attributes
- When a tag has long attributes, place the closing `>` on the same line as the last attribute
- Do NOT put the closing `>` on its own line

# JavaScript

- ES6+ syntax, ESM imports/exports, `const`/`let` (no `var`)
- Use `const` for fixed values — not `SCREAMING_SNAKE_CASE` constants (e.g., `const styleId = "foo"` not `const STYLE_ID = "foo"`)
- Strongly prefer Stimulus for JavaScript behavior — do not write raw/inline JS or jQuery
- Always use Tailwind CSS utility classes for styling — do not write custom CSS unless absolutely necessary
- Prefer Font Awesome (free) icons over inline SVGs — inline SVGs are acceptable when a specific icon design is preferred
- Prefer Turbo for navigation and form submissions before reaching for Stimulus
- Stimulus controller naming: `[name]_controller.js`

# Stimulus conventions
- Use `static targets` and `data-[controller]-target` — never `querySelector` or `getElementById` for elements that could be targets
- Use `static values = { name: Type }` for state — not instance variables. Use `[name]ValueChanged()` for reactive updates
- Use `data-action` attributes — not `addEventListener` in `connect()`. Omit default events (`click` for buttons, `input` for inputs, `submit` for forms, `change` for selects)
- Use `@window`/`@document` suffixes for global events in data-action
- Use action options (`:prevent`, `:stop`) instead of `event.preventDefault()` in methods
- Use `static classes` when CSS classes should be configurable from HTML
- Use `static outlets` for cross-controller communication instead of `getElementById`
- Always clean up in `disconnect()` anything created in `connect()` (listeners, timers, observers)
- Use `[name]TargetConnected`/`TargetDisconnected` for dynamic DOM (cocoon, Turbo)
- Toggle `hidden` class instead of `style.display`. Use `class="hidden"` not `style="display:none"` in HTML
