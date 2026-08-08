# expand-keyword

A Ruby CLI utility for managing `$KEYWORD` text expansions stored in a JSON file. The primary use case is Claude Code's `UserPromptSubmit` hook, which intercepts prompts before they reach Claude and injects the full expansion of any matched tokens as additional context. Tokens support recursive resolution and circular-reference detection.

## Project Structure

- `bin/expand-keyword` — Entry point, calls `ExpandKeyword::CLI.new.run(ARGV)`
- `lib/expand_keyword/cli.rb` — CLI dispatch, OptionParser definitions, all subcommand methods
- `lib/expand_keyword/config.rb` — XDG config path resolution, `Config` class
- `lib/expand_keyword/keyword_store.rb` — JSON persistence, CRUD operations on the keywords file
- `lib/expand_keyword/expander.rb` — Recursive token expansion with circular-reference detection
- `lib/expand_keyword/formatter.rb` — Output formatting for `list` and hook responses
- `lib/expand_keyword/version.rb` — `ExpandKeyword::VERSION` constant
- `test/` — Minitest unit tests, one file per lib file

## Key Details

- No runtime gem dependencies — stdlib only (`optparse`, `json`, `fileutils`)
- Tests use Minitest; run the suite with `bundle exec rake test`
- Run a single test file: `bundle exec ruby -Ilib:test test/<name>_test.rb`
- Lint: no linter currently configured; follow existing code style

## Adding a Subcommand

1. Add a `when "name"` branch in `CLI#run` that calls `run_name(argv)`
2. Add a private `run_name(argv)` method that parses options with `OptionParser` and does the work
3. Update the `usage` method to include the new subcommand in the help table
4. Add tests in `test/cli_test.rb` covering the happy path and error cases

## Config System

`Config` resolves the config file path in this order:

1. Explicit path passed to `Config.new(path)`
2. `XDG_CONFIG_HOME/expand-keyword/config` (if `XDG_CONFIG_HOME` is set)
3. `~/.config/expand-keyword/config` (default)

The config file records the keywords file location. The keywords file path is resolved in this order:

1. `EXPAND_KEYWORD_FILE` environment variable
2. Path recorded in the config file
3. `~/.config/expand-keyword/keywords.json` (default)

## Data Storage — keywords.json

```json
{
  "schemaVersion": 1,
  "$token": {
    "expansion": "full expansion text",
    "description": "human-readable description",
    "useCount": 0,
    "lastUsed": null
  }
}
```

Legacy string format (`"$token": "expansion text"`) is still supported and can be mixed with the object format in the same file.

## Subcommands

| Subcommand | Description |
|------------|-------------|
| `init` | Initialize config and keywords file |
| `config` | Show config path and contents |
| `list` | List all defined keywords |
| `add` | Add or update a keyword |
| `remove` | Remove a keyword |
| `expand` | Expand keywords in text; `--hook` for Claude Code integration |
| `edit` | Open the keywords file in `$VISUAL` / `$EDITOR` |
| `doctor` | Check binary, config, keywords file, and Claude hook registration |

## Pre-commit Requirements

Before every commit, run all four review agents in parallel using the Agent tool. Each agent should only review files changed in the current commit (or on the topic branch vs main). Pass this context when launching each agent.

1. `.claude/agents/new-user.md` — UX and first-run experience review
2. `.claude/agents/power-user.md` — Edge cases and composability review
3. `.claude/agents/testing-craftsperson.md` — Test coverage and suite health
4. `.claude/agents/staff-engineer.md` (use the global one at `~/source/opensource/workspace/.claude/agents/staff-engineer.md`) — Architecture and complexity review

All must pass before committing. Address any concerns raised before proceeding.

## Analysis and Research Output (Pyramid Principle)

When performing analysis, evaluation, or research — whether directly or via agent teams — structure output using the Pyramid Principle:

1. **Lead with the answer.** State the verdict/recommendation in 1-2 sentences at the very top.
2. **Follow with a compact recommendation list.** Actionable items, ordered by value, before any supporting detail.
3. **Then provide the detailed analysis.** Supporting evidence, trade-offs, and methodology come after.

The reader should be able to stop after the first two sections and have the full picture.
