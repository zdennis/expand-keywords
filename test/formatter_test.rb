require_relative "test_helper"
require "expand_keyword/keyword_store"
require "expand_keyword/formatter"

class FormatterTest < Minitest::Test
  def make_entry(token, expansion, description: nil)
    ExpandKeyword::KeywordEntry.new(
      token: token,
      expansion: expansion,
      description: description,
      use_count: 0,
      last_used: nil
    )
  end

  def test_list_with_empty_entries
    assert_equal "No keywords defined.", ExpandKeyword::Formatter.list({})
  end

  def test_list_shows_token_with_description
    entries = { "$greet" => make_entry("$greet", "Hello, world!", description: "A greeting") }
    result = ExpandKeyword::Formatter.list(entries)
    assert_includes result, "$greet"
    assert_includes result, "A greeting"
  end

  def test_list_truncates_expansion_when_no_description
    long_expansion = "a" * 100
    entries = { "$long" => make_entry("$long", long_expansion) }
    result = ExpandKeyword::Formatter.list(entries)
    assert_includes result, "$long"
    assert result.include?("..."), "Expected truncation with '...'"
    # Should not include the full 100-char expansion
    refute_includes result, long_expansion
  end

  def test_list_shows_short_expansion_when_no_description
    entries = { "$short" => make_entry("$short", "brief") }
    result = ExpandKeyword::Formatter.list(entries)
    assert_includes result, "brief"
  end

  def test_hook_response_with_empty_hash_returns_nil
    assert_nil ExpandKeyword::Formatter.hook_response({})
  end

  def test_hook_response_returns_valid_json
    found = { "$foo" => "bar expansion" }
    result = ExpandKeyword::Formatter.hook_response(found)
    refute_nil result
    parsed = JSON.parse(result)
    assert parsed.key?("hookSpecificOutput")
  end

  def test_hook_response_has_correct_structure
    found = { "$foo" => "bar expansion" }
    result = ExpandKeyword::Formatter.hook_response(found)
    parsed = JSON.parse(result)
    hook_output = parsed["hookSpecificOutput"]
    assert_equal "UserPromptSubmit", hook_output["hookEventName"]
    assert hook_output.key?("additionalContext")
  end

  def test_hook_response_includes_token_text_in_additional_context
    found = { "$mykey" => "my expanded value" }
    result = ExpandKeyword::Formatter.hook_response(found)
    parsed = JSON.parse(result)
    context = parsed["hookSpecificOutput"]["additionalContext"]
    assert_includes context, "$mykey"
    assert_includes context, "my expanded value"
  end
end
