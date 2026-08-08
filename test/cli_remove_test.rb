require_relative "test_helper"
require "expand_keyword/cli"

class CLIRemoveTest < Minitest::Test
  include TestHelpers

  def run_cli(argv)
    cli = ExpandKeyword::CLI.new
    cli.run(argv)
  end

  # remove

  def test_remove_prints_confirmation_and_removes_token
    with_keyword_file({ "$greet" => "Hello!", "$bye" => "Goodbye!" }) do |path|
      out, _err = capture_io do
        run_cli(["remove", "--file", path, "$greet"])
      end
      assert_includes out, "Removed $greet"
      raw = JSON.parse(File.read(path))
      refute raw.key?("$greet")
      assert raw.key?("$bye")
    end
  end

  def test_remove_with_nonexistent_token_prints_error_and_exits_1
    with_keyword_file({ "$existing" => "value" }) do |path|
      _out, err = capture_io do
        ex = assert_raises(SystemExit) do
          run_cli(["remove", "--file", path, "$missing"])
        end
        assert_equal 1, ex.status
      end
      assert_includes err, "not found"
    end
  end

  def test_remove_with_no_token_argument_prints_usage_error_and_exits_1
    with_keyword_file({}) do |path|
      _out, err = capture_io do
        ex = assert_raises(SystemExit) do
          run_cli(["remove", "--file", path])
        end
        assert_equal 1, ex.status
      end
      assert_includes err, "Error:"
    end
  end

  # init

  def test_init_creates_config_and_keywords_files_when_neither_exists
    dir = Dir.mktmpdir
    begin
      config_path = File.join(dir, "config.yml")
      keywords_path = File.join(dir, "keywords.json")
      out, _err = capture_io do
        run_cli(["init", "--config", config_path, "--file", keywords_path])
      end
      assert File.exist?(config_path), "config file should have been created"
      assert File.exist?(keywords_path), "keywords file should have been created"
      assert_includes out, config_path
      assert_includes out, keywords_path
    ensure
      FileUtils.rm_rf(dir)
    end
  end

  def test_init_reports_config_already_exists_and_does_not_overwrite
    dir = Dir.mktmpdir
    begin
      config_path = File.join(dir, "config.yml")
      keywords_path = File.join(dir, "keywords.json")
      original_content = "keywords_file: #{keywords_path}\n"
      File.write(config_path, original_content)
      out, _err = capture_io do
        run_cli(["init", "--config", config_path, "--file", keywords_path])
      end
      assert_includes out, "already exists"
      assert_equal original_content, File.read(config_path)
    ensure
      FileUtils.rm_rf(dir)
    end
  end

  # config

  def test_config_prints_config_file_path_and_keywords_file_path
    dir = Dir.mktmpdir
    begin
      config_path = File.join(dir, "config.yml")
      keywords_path = File.join(dir, "keywords.json")
      File.write(config_path, "keywords_file: #{keywords_path}\n")
      out, _err = capture_io do
        run_cli(["config", "--config", config_path])
      end
      assert_includes out, config_path
      assert_includes out, keywords_path
    ensure
      FileUtils.rm_rf(dir)
    end
  end
end
