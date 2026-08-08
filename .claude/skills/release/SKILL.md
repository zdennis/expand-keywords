---
name: release
description: Release expand-keyword by analyzing changes, bumping the version, tagging, and pushing
argument-hint: [patch|minor|major|<version>]
---

# Release expand-keyword

Analyze changes since the last release, suggest a version bump, and release.

## Usage

```
/release
/release patch
/release minor
/release major
/release <version>
```

## Instructions

When the user invokes this skill:

### Prerequisites

1. **Verify on main branch** — if not, inform the user and stop
2. **Verify no uncommitted changes** to tracked files — untracked files are fine

### If an argument is provided (patch, minor, major, or explicit version):

Skip change analysis and use the specified version directly:

1. **Get the current version** from `lib/expand_keyword/version.rb`
2. **Calculate the new version** based on the bump type (or use the explicit version)
3. **Update the version** in `lib/expand_keyword/version.rb`
4. **Commit** with message: `Bump version to <version>`
5. **Check if tag exists** — if the tag already exists, inform the user and stop
6. **Create tag** `v<version>`
7. **Push the commit** to origin (`git push`)
8. **Push the tag** to origin (`git push origin v<version>`)

### If NO argument is provided:

1. **Get the current version** from `lib/expand_keyword/version.rb`
2. **Find the last tag** matching `v*`
3. **Analyze changes since last tag**:
   - Run `git log <last-tag>..HEAD --oneline` to see commits
   - Run `git diff <last-tag>..HEAD -- lib/ bin/` to see what changed
   - If no previous tag exists, this is the initial release
4. **Suggest version bump** based on changes:
   - **Patch** (x.y.Z): Bug fixes, documentation, refactoring, internal cleanup
   - **Minor** (x.Y.0): New subcommands, new flags, new features (backward compatible)
   - **Major** (X.0.0): Breaking changes to the CLI interface, config file format, or keywords file location/format
5. **Show analysis to user**:
   - Display the current version
   - Summarize the changes since last tag
   - Show your recommended bump type with reasoning
   - Let the user confirm or choose a different version
6. **Update the version** in `lib/expand_keyword/version.rb` to the chosen version
7. **Commit** with message: `Bump version to <version>`
8. **Check if tag exists** — if the tag already exists, inform the user and stop
9. **Create tag** `v<version>`
10. **Push the commit** to origin (`git push`)
11. **Push the tag** to origin (`git push origin v<version>`)

## Version File

The version is stored in `lib/expand_keyword/version.rb`:

```ruby
module ExpandKeyword
  VERSION = "0.1.0"
end
```

Update only the version string when bumping.

## Change Analysis Guidelines

### Patch (bug fixes, internal changes)
- Fixed typos or documentation
- Refactored code without changing behavior
- Fixed bugs that made the tool not work as documented
- Performance improvements or code cleanup

### Minor (new features, backward compatible)
- New subcommands added
- New command-line flags or options
- New token syntax or expansion features
- New functionality that doesn't affect existing behavior

### Major (breaking changes)
- Removed subcommands or flags
- Changed default keywords file location (`~/.claude/expand-keywords.json`)
- Changed keywords JSON schema in a backward-incompatible way
- Changed exit codes
- Renamed subcommands or flags
- Changed hook output format (breaks Claude Code integration)

## Error Handling

- If not on main branch, inform the user and stop
- If the tag already exists, inform the user (this version has already been released)
- If there are uncommitted tracked changes, inform the user and stop

## No Previous Tag

If this is the first release (no previous tag exists):

1. Inform the user this is the initial release
2. Skip change analysis (nothing to compare against)
3. Use the current version as the release version
4. Proceed with tag creation and push
