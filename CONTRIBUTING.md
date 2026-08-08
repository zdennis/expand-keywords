# Contributing to expand-keywords

Thank you for your interest in contributing!

## Getting started

1. Fork and clone the repository
2. Run `bundle install`
3. Run the tests to confirm everything passes

## Running tests

Run all tests at once:

```bash
bundle exec rake test
```

Or run individual test files:

```bash
bundle exec ruby -Ilib:test test/keyword_store_test.rb
bundle exec ruby -Ilib:test test/expander_test.rb
bundle exec ruby -Ilib:test test/formatter_test.rb
bundle exec ruby -Ilib:test test/cli_test.rb
```

## Submitting changes

1. Create a feature branch (`git checkout -b your-feature-name`)
2. Make your changes and ensure all tests pass
3. Submit a pull request with a clear description of what changed and why

Please confirm tests are passing before requesting review.
