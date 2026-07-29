# expand-keyword

A Ruby CLI utility for managing `$KEYWORD` text expansions stored in a JSON file. The primary use case is Claude Code's `UserPromptSubmit` hook, which lets you define shorthand aliases that automatically inject full context into any prompt you type.

## What it does

You define tokens like `$ctx`, `$persona`, or `$stack` once. When you use them in a Claude Code prompt, the hook intercepts the prompt before it reaches Claude and injects the full expansion as additional context. Claude then treats the token as if you'd typed the full text.

Tokens can reference other tokens — expansions are resolved recursively.

## Installation

Clone the repo and either run directly or symlink to your PATH:

```bash
git clone https://github.com/youruser/expand-keywords.git
cd expand-keywords

# Option 1: symlink to PATH
ln -s "$(pwd)/bin/expand-keyword" /usr/local/bin/expand-keyword

# Option 2: run directly
./bin/expand-keyword --help
```

Ruby >= 3.0 required. No runtime gem dependencies.

## Usage

### List all keywords

```bash
expand-keyword list
expand-keyword list --file /path/to/keywords.json
```

### Add or update a keyword

```bash
expand-keyword add '$ctx' "You are working in a Rails 7 API-only app using Postgres and Sidekiq."
expand-keyword add --description "Rails app context" '$ctx' "You are working in a Rails 7 API-only app."
expand-keyword add --file /path/to/keywords.json '$mykey' "expansion text"
```

Token must start with `$` and match `$[A-Za-z_][A-Za-z0-9_:\-]*`.

### Expand keywords in text

```bash
expand-keyword expand "Tell me about $ctx"
expand-keyword expand --file /path/to/keywords.json "What is $mykey"
```

### Claude Code hook mode

Reads a JSON payload from stdin (Claude Code's `UserPromptSubmit` format) and writes hook JSON to stdout. Tokens that don't match any keyword are ignored.

```bash
echo '{"prompt": "help me with $ctx"}' | expand-keyword expand --hook
```

## JSON file format

By default, keywords are stored at `~/.claude/expand-keywords.json`.

**Object format (full):**

```json
{
  "schemaVersion": 1,
  "$ctx": {
    "expansion": "You are working in a Rails 7 API-only app.",
    "description": "Rails app context",
    "useCount": 0,
    "lastUsed": null
  }
}
```

**Legacy string format (still supported):**

```json
{
  "$ctx": "You are working in a Rails 7 API-only app."
}
```

Both formats can be mixed in the same file.

## Claude Code hook integration

Add this to your Claude Code `settings.json` (typically `~/.claude/settings.json`):

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "expand-keyword expand --hook"
          }
        ]
      }
    ]
  }
}
```

If you store your keywords in a non-default location:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "expand-keyword expand --hook --file /path/to/keywords.json"
          }
        ]
      }
    ]
  }
}
```

When you type a prompt containing a `$KEYWORD` token, the hook fires before Claude sees it. If the token is defined, Claude receives additional context explaining what the token expands to.

## Recursive expansion

Tokens can reference other tokens:

```bash
expand-keyword add '$stack' "Rails 7, Postgres, Sidekiq"
expand-keyword add '$ctx' "You are working with $stack on an API-only app."

expand-keyword expand "$ctx"
# => You are working with Rails 7, Postgres, Sidekiq on an API-only app.
```

Circular references are detected and stopped — the token is left unexpanded rather than looping forever.

## Escaping

Use `\$` to prevent expansion:

```bash
expand-keyword expand "The token \$ctx is defined as..."
# => The token $ctx is defined as...
```

## Running tests

```bash
bundle install
bundle exec ruby -Ilib:test test/keyword_store_test.rb
bundle exec ruby -Ilib:test test/expander_test.rb
bundle exec ruby -Ilib:test test/formatter_test.rb
bundle exec ruby -Ilib:test test/cli_test.rb
```
