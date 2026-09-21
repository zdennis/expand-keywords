require_relative "test_helper"
require "expand_keyword/keyword_store"

class KeywordStoreTest < Minitest::Test
  include TestHelpers

  def test_all_returns_empty_hash_when_file_does_not_exist
    empty_keyword_file do |path|
      store = ExpandKeyword::KeywordStore.new(path)
      assert_equal({}, store.all)
    end
  end

  def test_all_skips_schema_version
    with_keyword_file({ "schemaVersion" => 1, "$foo" => "bar" }) do |path|
      store = ExpandKeyword::KeywordStore.new(path)
      refute store.all.key?("schemaVersion")
      assert store.all.key?("$foo")
    end
  end

  def test_all_normalizes_legacy_string_values
    with_keyword_file({ "$greet" => "Hello, world!" }) do |path|
      store = ExpandKeyword::KeywordStore.new(path)
      entry = store.all["$greet"]
      assert_instance_of ExpandKeyword::KeywordEntry, entry
      assert_equal "Hello, world!", entry.expansion
      assert_nil entry.description
      assert_equal 0, entry.use_count
    end
  end

  def test_all_normalizes_object_format_values
    data = {
      "$cmd" => {
        "expansion" => "run the tests",
        "description" => "Run test suite",
        "useCount" => 5,
        "lastUsed" => "2024-01-01"
      }
    }
    with_keyword_file(data) do |path|
      store = ExpandKeyword::KeywordStore.new(path)
      entry = store.all["$cmd"]
      assert_equal "run the tests", entry.expansion
      assert_equal "Run test suite", entry.description
      assert_equal 5, entry.use_count
      assert_equal "2024-01-01", entry.last_used
    end
  end

  def test_find_exact_match
    with_keyword_file({ "$hello" => "world" }) do |path|
      store = ExpandKeyword::KeywordStore.new(path)
      entry = store.find("$hello")
      refute_nil entry
      assert_equal "world", entry.expansion
    end
  end

  def test_find_case_insensitive_fallback
    with_keyword_file({ "$Hello" => "world" }) do |path|
      store = ExpandKeyword::KeywordStore.new(path)
      entry = store.find("$hello")
      refute_nil entry
      assert_equal "world", entry.expansion
    end
  end

  def test_find_returns_nil_for_unknown_token
    with_keyword_file({ "$known" => "value" }) do |path|
      store = ExpandKeyword::KeywordStore.new(path)
      assert_nil store.find("$unknown")
    end
  end

  def test_add_creates_file_when_it_does_not_exist
    empty_keyword_file do |path|
      store = ExpandKeyword::KeywordStore.new(path)
      store.add("$new", "expansion text")
      assert File.exist?(path)
      entry = store.find("$new")
      assert_equal "expansion text", entry.expansion
    end
  end

  def test_add_updates_existing_without_destroying_others
    with_keyword_file({ "$a" => "alpha", "$b" => "beta" }) do |path|
      store = ExpandKeyword::KeywordStore.new(path)
      store.add("$a", "ALPHA UPDATED")
      assert_equal "ALPHA UPDATED", store.find("$a").expansion
      assert_equal "beta", store.find("$b").expansion
    end
  end

  def test_save_writes_schema_version_as_first_key
    empty_keyword_file do |path|
      store = ExpandKeyword::KeywordStore.new(path)
      store.add("$x", "val")
      raw = JSON.parse(File.read(path))
      assert_equal 1, raw["schemaVersion"]
      assert_equal "schemaVersion", raw.keys.first
    end
  end

  def test_record_use_increments_count_and_stamps_last_used
    empty_keyword_file do |path|
      store = ExpandKeyword::KeywordStore.new(path)
      store.add("$greet", "Hello!")
      before = Time.now.utc

      assert store.record_use("$greet")

      raw = JSON.parse(File.read(path))["$greet"]
      assert_equal 1, raw["useCount"]
      # iso8601 truncates subseconds, so compare against a floored timestamp
      last_used = Time.parse(raw["lastUsed"])
      assert last_used >= before.floor
    end
  end

  def test_record_use_preserves_count_across_loads
    with_keyword_file({ "$cmd" => { "expansion" => "run", "useCount" => 5, "lastUsed" => "2024-01-01" } }) do |path|
      store = ExpandKeyword::KeywordStore.new(path)
      store.record_use("$cmd")
      reloaded = ExpandKeyword::KeywordStore.new(path)
      assert_equal 6, reloaded.find("$cmd").use_count
      refute_equal "2024-01-01", reloaded.find("$cmd").last_used
    end
  end

  def test_record_use_returns_false_for_unknown_token
    with_keyword_file({ "$known" => "value" }) do |path|
      store = ExpandKeyword::KeywordStore.new(path)
      refute store.record_use("$unknown")
      raw = JSON.parse(File.read(path))
      assert_equal "value", raw["$known"]
      assert_nil raw["$known"]["useCount"]
    end
  end

  def test_save_serializes_to_object_format
    empty_keyword_file do |path|
      store = ExpandKeyword::KeywordStore.new(path)
      store.add("$token", "the expansion", description: "A description")
      raw = JSON.parse(File.read(path))
      entry_data = raw["$token"]
      assert_instance_of Hash, entry_data
      assert_equal "the expansion", entry_data["expansion"]
      assert_equal "A description", entry_data["description"]
    end
  end
end
