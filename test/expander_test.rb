require_relative "test_helper"
require "expand_keyword/keyword_store"
require "expand_keyword/expander"

class ExpanderTest < Minitest::Test
  include TestHelpers

  def setup
    @dir = Dir.mktmpdir
    @path = File.join(@dir, "expand-keywords.json")
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def store_with(data)
    File.write(@path, JSON.generate(data))
    ExpandKeyword::KeywordStore.new(@path)
  end

  def empty_store
    ExpandKeyword::KeywordStore.new(@path)
  end

  def test_no_tokens_returns_unchanged
    store = empty_store
    expander = ExpandKeyword::Expander.new(store)
    assert_equal "plain text here", expander.expand("plain text here")
  end

  def test_single_known_token_replaced
    store = store_with({ "$greet" => "Hello, world!" })
    expander = ExpandKeyword::Expander.new(store)
    assert_equal "Say: Hello, world!", expander.expand("Say: $greet")
  end

  def test_unknown_token_left_as_is
    store = empty_store
    expander = ExpandKeyword::Expander.new(store)
    assert_equal "text with $unknown token", expander.expand("text with $unknown token")
  end

  def test_escaped_dollar_not_expanded
    store = store_with({ "$foo" => "bar" })
    expander = ExpandKeyword::Expander.new(store)
    assert_equal "literal $foo here", expander.expand("literal \\$foo here")
  end

  def test_token_in_expansion_recursively_expanded
    store = store_with({ "$a" => "alpha and $b", "$b" => "beta" })
    expander = ExpandKeyword::Expander.new(store)
    assert_equal "alpha and beta", expander.expand("$a")
  end

  def test_circular_reference_terminates_without_infinite_loop
    store = store_with({ "$loop" => "going $loop forever" })
    expander = ExpandKeyword::Expander.new(store)
    result = expander.expand("$loop")
    # Should not raise and should stop recursion
    assert_equal "going $loop forever", result
  end

  def test_multi_level_recursion_three_levels
    store = store_with({ "$a" => "$b", "$b" => "$c", "$c" => "deep value" })
    expander = ExpandKeyword::Expander.new(store)
    assert_equal "deep value", expander.expand("$a")
  end

  def test_case_insensitive_lookup
    store = store_with({ "$UPPER" => "uppercase expansion" })
    expander = ExpandKeyword::Expander.new(store)
    assert_equal "uppercase expansion", expander.expand("$upper")
  end

  def test_multiple_different_tokens_expanded
    store = store_with({ "$foo" => "FOO", "$bar" => "BAR" })
    expander = ExpandKeyword::Expander.new(store)
    assert_equal "FOO and BAR", expander.expand("$foo and $bar")
  end

  def test_same_token_twice_both_expanded
    store = store_with({ "$x" => "VALUE" })
    expander = ExpandKeyword::Expander.new(store)
    assert_equal "VALUE and VALUE", expander.expand("$x and $x")
  end
end
