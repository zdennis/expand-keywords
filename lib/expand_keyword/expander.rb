require "set"

module ExpandKeyword
  class Expander
    TOKEN_REGEX = /\$[A-Za-z_][A-Za-z0-9_:\-]*/
    ESCAPE_PLACEHOLDER = "\x00DOLLAR\x00"

    def initialize(store)
      @store = store
    end

    def expand(text, visiting: Set.new)
      working = text.gsub("\\$", ESCAPE_PLACEHOLDER)

      result = working.gsub(TOKEN_REGEX) do |match|
        entry = @store.find(match)
        if entry.nil?
          match
        elsif visiting.include?(match.downcase)
          match
        else
          expand(entry.expansion, visiting: visiting | Set[match.downcase])
        end
      end

      result.gsub(ESCAPE_PLACEHOLDER, "$")
    end

    # Collect the top-level tokens found in text and their fully-expanded values.
    # Returns a Hash of token => expanded_string for tokens that were found.
    # When namespace is given, colon-less tokens resolve as $namespace:token
    # first, falling back to the token as written.
    def found_tokens(text, namespace: nil)
      working = text.gsub("\\$", ESCAPE_PLACEHOLDER)
      tokens = working.scan(TOKEN_REGEX).uniq
      result = {}
      tokens.each do |token|
        entry = lookup(token, namespace)
        next if entry.nil?
        result[token] = expand(entry.expansion, visiting: Set[token.downcase])
      end
      result
    end

    # Resolve a $-prefixed token against a namespace: colon-less tokens
    # resolve as $namespace:token first, falling back to the token as given.
    def resolve_token(token, namespace)
      return token if namespace.nil? || token.include?(":")

      namespaced = "$#{namespace}:#{token.delete_prefix("$")}"
      @store.find(namespaced) ? namespaced : token
    end

    private

    def lookup(token, namespace)
      @store.find(resolve_token(token, namespace))
    end
  end
end
