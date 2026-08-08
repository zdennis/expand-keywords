# frozen_string_literal: true

require "fileutils"
require "yaml"

module ExpandKeyword
  class Config
    CONFIG_FILENAME = "config.yml"
    KEYWORDS_FILENAME = "keywords.json"

    def self.config_dir
      xdg = ENV.fetch("XDG_CONFIG_HOME", File.expand_path("~/.config"))
      File.join(xdg, "expand-keyword")
    end

    def self.default_config_path
      File.join(config_dir, CONFIG_FILENAME)
    end

    def self.default_keywords_path
      if ENV["EXPAND_KEYWORD_FILE"]
        File.expand_path(ENV["EXPAND_KEYWORD_FILE"])
      else
        config = new
        config.keywords_path
      end
    end

    attr_reader :path

    def initialize(path = self.class.default_config_path)
      @path = path
    end

    def keywords_path
      if data["keywords_file"]
        File.expand_path(data["keywords_file"])
      else
        File.join(self.class.config_dir, KEYWORDS_FILENAME)
      end
    end

    def exists?
      File.exist?(@path)
    end

    def create!
      return false if exists?
      FileUtils.mkdir_p(File.dirname(@path))
      File.write(@path, default_content)
      true
    end

    def to_s
      exists? ? File.read(@path) : "(config file not found)"
    end

    private

    def data
      @data ||= exists? ? (YAML.safe_load(File.read(@path)) || {}) : {}
    end

    def default_content
      default_keywords = File.join(self.class.config_dir, KEYWORDS_FILENAME)
      <<~YAML
        # expand-keyword configuration
        # Uncomment and edit keywords_file to use a custom path.
        # keywords_file: /path/to/your/keywords.json
        keywords_file: #{default_keywords}
      YAML
    end
  end
end
