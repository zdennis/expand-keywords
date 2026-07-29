require_relative "test_helper"
require "expand_keyword/cli"

class CLITest < Minitest::Test
  include TestHelpers

  def run_cli(argv)
    cli = ExpandKeyword::CLI.new
    cli.run(argv)
  end

  def test_list_prints_keywords_to_stdout
    with_keyword_file({ "$hello" => "world" }) do |path|
      out, _err = capture_io do
        run_cli(["list", "--file", path])
      end
      assert_includes out, "$hello"
    end
  end

  def test_list_prints_no_keywords_message_when_empty
    empty_keyword_file do |path|
      out, _err = capture_io do
        run_cli(["list", "--file", path])
      end
      assert_includes out, "No keywords defined."
    end
  end

  def test_add_creates_file_and_stores_keyword
    empty_keyword_file do |path|
      out, _err = capture_io do
        run_cli(["add", "--file", path, "$newkey", "new expansion"])
      end
      assert_includes out, "Added $newkey"
      assert File.exist?(path)
      raw = JSON.parse(File.read(path))
      assert raw.key?("$newkey")
    end
  end

  def test_add_with_description_stores_description
    empty_keyword_file do |path|
      capture_io do
        run_cli(["add", "--file", path, "--description", "My desc", "$key", "the value"])
      end
      raw = JSON.parse(File.read(path))
      assert_equal "My desc", raw["$key"]["description"]
    end
  end

  def test_add_missing_dollar_prefix_exits_with_error
    empty_keyword_file do |path|
      _out, err = capture_io do
        assert_raises(SystemExit) do
          run_cli(["add", "--file", path, "nodollar", "expansion"])
        end
      end
      assert_includes err, "Error:"
    end
  end

  def test_expand_with_text_argument_expands_and_prints
    with_keyword_file({ "$greet" => "Hello!" }) do |path|
      out, _err = capture_io do
        run_cli(["expand", "--file", path, "Say $greet"])
      end
      assert_includes out, "Hello!"
    end
  end

  def test_expand_hook_reads_stdin_and_outputs_hook_json
    with_keyword_file({ "$ctx" => "some context" }) do |path|
      payload = JSON.generate({ "prompt" => "use $ctx please" })
      old_stdin = $stdin
      $stdin = StringIO.new(payload)
      begin
        out, _err = capture_io do
          run_cli(["expand", "--file", path, "--hook"])
        end
        assert out.length > 0, "Expected hook JSON output"
        parsed = JSON.parse(out)
        assert parsed.key?("hookSpecificOutput")
      ensure
        $stdin = old_stdin
      end
    end
  end

  def test_expand_hook_outputs_nothing_when_no_tokens_found
    empty_keyword_file do |path|
      payload = JSON.generate({ "prompt" => "no keywords here" })
      old_stdin = $stdin
      $stdin = StringIO.new(payload)
      begin
        out, _err = capture_io do
          run_cli(["expand", "--file", path, "--hook"])
        end
        assert_equal "", out
      ensure
        $stdin = old_stdin
      end
    end
  end

  def test_unknown_subcommand_exits_1
    _out, _err = capture_io do
      ex = assert_raises(SystemExit) do
        run_cli(["unknowncmd"])
      end
      assert_equal 1, ex.status
    end
  end

  def test_version_flag_prints_version
    out, _err = capture_io do
      run_cli(["--version"])
    end
    assert_includes out, ExpandKeyword::VERSION
  end

  def test_help_flag_prints_usage
    out, _err = capture_io do
      run_cli(["--help"])
    end
    assert_includes out, "expand-keyword"
    assert_includes out, "Subcommands:"
  end
end
