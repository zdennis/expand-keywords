require "json"
require "time"
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

    # Increment use_count and stamp last_used for tokens that resolved,
    # with a single save at the end. Returns true if any token was recorded.
    def record_uses(tokens)
      now = Time.now.utc.iso8601
      recorded = false
      tokens.each do |token|
        entry = find(token)
        next if entry.nil?

        entry.use_count = (entry.use_count || 0) + 1
        entry.last_used = now
        recorded = true
      end
      save if recorded
      recorded
    end

    # Convenience wrapper for recording a single token.
    def record_use(token)
      record_uses([token])
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
