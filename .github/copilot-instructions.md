# This project is a Ruby on Rails application.

# PRs
- After completing work, create a pull request using `gh pr create`
- Once the PR is created, prepend the PR number to the branch name (e.g., rename `maebeale/fix-login` to `maebeale/1234-fix-login`) using `git branch -m` and `git push origin -u` with the new name, then delete the old remote branch

# Code style requirements:
- Use modern Ruby syntax
- Prefer early returns and guard clauses
- Avoid unnecessary and/or complex conditionals
- Prefer enums and scopes over magic strings
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
