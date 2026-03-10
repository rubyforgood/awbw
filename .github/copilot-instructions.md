# This project is a Ruby on Rails application.
<!-- Keep code style rules in sync with CLAUDE.md -->

# Frontend requirements:
- Strongly prefer Stimulus for JavaScript behavior — do not write raw/inline JS or jQuery
- Always use Tailwind CSS utility classes for styling — do not write custom CSS unless absolutely necessary
- Prefer Turbo for navigation and form submissions before reaching for Stimulus
- ES6+ syntax, ESM imports/exports
- Stimulus controller naming: `[name]_controller.js`

# Stimulus conventions:
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

# PRs
- After completing work, create a pull request using `gh pr create`
- Once the PR is created, prepend the PR number to the branch name (e.g., rename `maebeale/fix-login` to `maebeale/1234-fix-login`) using `git branch -m` and `git push origin -u` with the new name, then delete the old remote branch
- On every push, update the PR title and content to reflect the current diff
- On every push, update AI instruction files if the diff introduces changes that affect conventions, architecture, or file lists documented there

# Code style requirements:
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

# Git
- When rebasing onto main, review incoming changes for their intent and flag any oversights — missing tests, incomplete migrations, broken assumptions, or conflicts between the two branches. Check both directions: schema/model changes on either branch that affect views, partials, or layouts on the other (e.g., main redesigned a table's CSS but your branch adds new columns to it, or vice versa)

# HTML/ERB Formatting

## Tag attributes
- When a tag has long attributes, place the closing `>` on the same line as the last attribute
- Do NOT put the closing `>` on its own line
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
