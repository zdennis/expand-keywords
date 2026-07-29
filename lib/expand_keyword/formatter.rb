require "json"

module ExpandKeyword
  class Formatter
    DESCRIPTION_MAX = 80

    def self.list(entries)
      return "No keywords defined." if entries.empty?
      entries.map do |token, entry|
        label = entry.description || truncate(entry.expansion, DESCRIPTION_MAX)
        "#{token}  #{label}"
      end.join("\n")
    end

    def self.hook_response(found_tokens)
      return nil if found_tokens.empty?
      parts = found_tokens.map { |token, expansion| "#{token} means: #{expansion}" }
      additional_context = "The following $KEYWORD text expansion aliases are defined. When the user includes one in a prompt, treat it as the instruction or context it maps to:\n\n  - " + parts.join("\n\n  - ")
      JSON.generate({
        hookSpecificOutput: {
          hookEventName: "UserPromptSubmit",
          additionalContext: additional_context
        }
      })
    end

    def self.expanded(text)
      text
    end

    private_class_method def self.truncate(str, max)
      return str if str.length <= max
      str[0, max - 3] + "..."
    end
  end
end
