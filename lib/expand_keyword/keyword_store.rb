require "json"
require "fileutils"
require_relative "config"

module ExpandKeyword
  KeywordEntry = Struct.new(:token, :expansion, :description, :use_count, :last_used, keyword_init: true)

  class KeywordStore
    def self.default_path
      Config.default_keywords_path
    end
    RESERVED_KEYS = %w[schemaVersion].freeze

    attr_reader :path

    def initialize(path = self.class.default_path)
      @path = path
      @entries = nil
    end

    def all
      @entries ||= load
    end

    def find(token)
      entries = all
      # exact match first
      return entries[token] if entries.key?(token)
      # case-insensitive fallback
      key = entries.keys.find { |k| k.casecmp(token) == 0 }
      key ? entries[key] : nil
    end

    def add(token, expansion, description: nil)
      entries = all
      existing = entries[token]
      entries[token] = KeywordEntry.new(
        token: token,
        expansion: expansion,
        description: description || (existing&.description),
        use_count: existing&.use_count || 0,
        last_used: existing&.last_used
      )
      save
    end

    def delete(token)
      entries = all
      return false unless entries.key?(token)
      entries.delete(token)
      save
      true
    end

    def save
      FileUtils.mkdir_p(File.dirname(@path))
      data = { "schemaVersion" => 1 }
      all.each do |token, entry|
        data[token] = {
          "expansion" => entry.expansion,
          "description" => entry.description,
          "useCount" => entry.use_count,
          "lastUsed" => entry.last_used
        }
      end
      File.write(@path, JSON.pretty_generate(data))
    end

    private

    def load
      return {} unless File.exist?(@path)
      raw = JSON.parse(File.read(@path))
      raw.each_with_object({}) do |(k, v), acc|
        next if RESERVED_KEYS.include?(k)
        acc[k] = normalize(k, v)
      end
    end

    def normalize(token, value)
      case value
      when String
        KeywordEntry.new(token: token, expansion: value, description: nil, use_count: 0, last_used: nil)
      when Hash
        KeywordEntry.new(
          token: token,
          expansion: value["expansion"].to_s,
          description: value["description"],
          use_count: value["useCount"] || 0,
          last_used: value["lastUsed"]
        )
      else
        KeywordEntry.new(token: token, expansion: value.to_s, description: nil, use_count: 0, last_used: nil)
      end
    end
  end
end
