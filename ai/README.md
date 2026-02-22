# ai/ — Command Shortcuts

Quick-reference scripts for common development tasks. Designed for AI agents and humans alike.

| Command | What it does |
|---|---|
| `ai/test [args]` | Run RSpec tests (`ai/test spec/models/user_spec.rb:42`) |
| `ai/lint` | Rubocop on all files |
| `ai/lint --fix` | Auto-fix lint issues |
| `ai/server` | Start all dev services (web + vite) |
| `ai/console` | Rails console |
| `ai/routes -g pattern` | Search Rails routes |
| `ai/db-migrate` | Run database migrations |

All scripts pass through extra arguments, so `ai/test --fail-fast` works as expected.
