require_relative "test_helper"
require "expand_keyword/config"

class ConfigTest < Minitest::Test
  include TestHelpers

  def with_temp_dir
    dir = Dir.mktmpdir
    yield dir
  ensure
    FileUtils.rm_rf(dir)
  end

  def with_env(key, value)
    old = ENV[key]
    ENV[key] = value
    yield
  ensure
    if old.nil?
      ENV.delete(key)
    else
      ENV[key] = old
    end
  end

  # config_dir

  def test_config_dir_uses_xdg_config_home_when_set
    with_temp_dir do |dir|
      with_env("XDG_CONFIG_HOME", dir) do
        assert_equal File.join(dir, "expand-keyword"), ExpandKeyword::Config.config_dir
      end
    end
  end

  def test_config_dir_falls_back_to_default_dot_config
    with_env("XDG_CONFIG_HOME", nil) do
      expected = File.join(File.expand_path("~/.config"), "expand-keyword")
      assert_equal expected, ExpandKeyword::Config.config_dir
    end
  end

  # default_config_path

  def test_default_config_path_is_inside_config_dir
    path = ExpandKeyword::Config.default_config_path
    assert_equal File.join(ExpandKeyword::Config.config_dir, "config.yml"), path
  end

  # default_keywords_path

  def test_default_keywords_path_honors_expand_keyword_file_env_var
    with_temp_dir do |dir|
      custom = File.join(dir, "my-keywords.json")
      with_env("EXPAND_KEYWORD_FILE", custom) do
        assert_equal custom, ExpandKeyword::Config.default_keywords_path
      end
    end
  end

  def test_default_keywords_path_returns_config_dir_keywords_when_no_config_exists
    with_temp_dir do |dir|
      with_env("XDG_CONFIG_HOME", dir) do
        with_env("EXPAND_KEYWORD_FILE", nil) do
          config_path = File.join(dir, "expand-keyword", "config.yml")
          # config file does not exist, so keywords_path falls back to default
          expected = File.join(dir, "expand-keyword", "keywords.json")
          assert_equal expected, ExpandKeyword::Config.default_keywords_path
        end
      end
    end
  end

  # exists?

  def test_exists_returns_false_when_file_does_not_exist
    with_temp_dir do |dir|
      path = File.join(dir, "config.yml")
      config = ExpandKeyword::Config.new(path)
      refute config.exists?
    end
  end

  def test_exists_returns_true_when_file_exists
    with_temp_dir do |dir|
      path = File.join(dir, "config.yml")
      File.write(path, "# config\n")
      config = ExpandKeyword::Config.new(path)
      assert config.exists?
    end
  end

  # create!

  def test_create_creates_the_file_and_returns_true
    with_temp_dir do |dir|
      path = File.join(dir, "config.yml")
      config = ExpandKeyword::Config.new(path)
      result = config.create!
      assert result
      assert File.exist?(path)
    end
  end

  def test_create_returns_false_and_does_not_overwrite_when_file_already_exists
    with_temp_dir do |dir|
      path = File.join(dir, "config.yml")
      File.write(path, "original: true\n")
      config = ExpandKeyword::Config.new(path)
      result = config.create!
      refute result
      assert_equal "original: true\n", File.read(path)
    end
  end

  # keywords_path

  def test_keywords_path_returns_custom_path_when_keywords_file_set_in_config
    with_temp_dir do |dir|
      custom_keywords = File.join(dir, "my-keywords.json")
      path = File.join(dir, "config.yml")
      File.write(path, "keywords_file: #{custom_keywords}\n")
      config = ExpandKeyword::Config.new(path)
      assert_equal custom_keywords, config.keywords_path
    end
  end

  def test_keywords_path_falls_back_to_default_when_no_keywords_file_in_config
    with_temp_dir do |dir|
      with_env("XDG_CONFIG_HOME", dir) do
        path = File.join(dir, "expand-keyword", "config.yml")
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, "# no keywords_file key\n")
        config = ExpandKeyword::Config.new(path)
        expected = File.join(dir, "expand-keyword", "keywords.json")
        assert_equal expected, config.keywords_path
      end
    end
  end

  # to_s

  def test_to_s_returns_file_contents_when_exists
    with_temp_dir do |dir|
      path = File.join(dir, "config.yml")
      content = "keywords_file: /some/path.json\n"
      File.write(path, content)
      config = ExpandKeyword::Config.new(path)
      assert_equal content, config.to_s
    end
  end

  def test_to_s_returns_not_found_message_when_missing
    with_temp_dir do |dir|
      path = File.join(dir, "config.yml")
      config = ExpandKeyword::Config.new(path)
      assert_equal "(config file not found)", config.to_s
    end
  end
end
