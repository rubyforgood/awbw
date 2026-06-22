# ai/ — Command Shortcuts

Quick-reference scripts for common development tasks. Designed for AI agents and humans alike.

| Command | What it does |
|---|---|
| `ai/recap` | Session recap: accomplishments + unresolved items (agent behavior; see below) |
| `ai/review` | Code review: agent reviews the workspace diff, posts inline comments, and gives a Recap + Risks + Outstanding decisions summary (agent behavior; see below) |
| `ai/test [args]` | Run RSpec tests (`ai/test spec/models/user_spec.rb:42`) |
| `ai/lint` | Rubocop on all files |
| `ai/lint --fix` | Auto-fix lint issues |
| `ai/server` | Start all dev services (web + vite) |
| `ai/console` | Rails console |
| `ai/routes -g pattern` | Search Rails routes |
| `ai/migrate` | Run database migrations |
| `ai/seed` | Load the full dev sample dataset (`db:seed:dev`) into the workspace DB |
| `ai/security` | Security scan: Brakeman + bundler-audit (mirrors CI) |

All scripts pass through extra arguments, so `ai/test --fail-fast` works as expected.

Only the commands listed above exist. "ai <name>" refers to one of these `ai/` scripts — not a slash-command skill. Two phrases are special:

- **"ai security"** runs `ai/security` (the security scan above).
- **"ai review"** (or `ai/review`, which just prints a trigger) tells the agent to run the `ai-review` skill (`.claude/skills/ai-review/SKILL.md`): review the current workspace diff against the review guidelines, post one concise inline comment per qualifying bug, then give a written **Recap + Risks + Outstanding decisions** summary (modeled on `ai recap`). It is never the `/audit` design skill or `ai/security`.
- **"ai recap"** (or `ai/recap`, which just prints the trigger word) tells the agent to review the conversation and report two parts: **Recap** (what was accomplished) and **Unresolved** (dropped threads, unanswered questions, unfinished tasks, and disagreements from either side). The agent performs it directly per `CLAUDE.md`. It is never the `/audit` design/accessibility skill.
