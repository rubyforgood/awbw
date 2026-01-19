# This project is a Ruby on Rails application.

# Code style requirements:
- Use modern Ruby syntax
- Follow RuboCop (with  rubocop-rails-omakase and rubocop-rails and rubocop-performance)
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
