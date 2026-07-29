require "optparse"
require "json"
require_relative "version"
require_relative "keyword_store"
require_relative "expander"
require_relative "formatter"

module ExpandKeyword
  class CLI
    def run(argv)
      argv = argv.dup
      subcommand = argv.shift

      case subcommand
      when "list"
        run_list(argv)
      when "add"
        run_add(argv)
      when "expand"
        run_expand(argv)
      when "--version", "-v"
        puts ExpandKeyword::VERSION
      when nil, "--help", "-h"
        puts usage
      else
        warn "Unknown subcommand: #{subcommand}"
        warn usage
        exit 1
      end
    rescue => e
      warn "Error: #{e.message}"
      exit 1
    end

    private

    def run_list(argv)
      options = { file: KeywordStore::DEFAULT_PATH }
      OptionParser.new do |o|
        o.on("--file PATH", "Path to keywords JSON file") { |v| options[:file] = v }
      end.parse!(argv)

      store = KeywordStore.new(options[:file])
      puts Formatter.list(store.all)
    end

    def run_add(argv)
      options = { file: KeywordStore::DEFAULT_PATH }
      OptionParser.new do |o|
        o.on("--file PATH", "Path to keywords JSON file") { |v| options[:file] = v }
        o.on("--description DESC", "Human-readable description") { |v| options[:description] = v }
      end.parse!(argv)

      token = argv[0]
      expansion = argv[1]

      raise "Usage: expand-keyword add --file PATH \$TOKEN \"expansion text\"" if token.nil? || expansion.nil?
      raise "Token must start with $ (e.g. $keyword)" unless token.start_with?("$")
      raise "Token contains invalid characters" unless token.match?(/\A\$[A-Za-z_][A-Za-z0-9_:\-]*\z/)

      store = KeywordStore.new(options[:file])
      store.add(token, expansion, description: options[:description])
      puts "Added #{token}"
    end

    def run_expand(argv)
      options = { file: KeywordStore::DEFAULT_PATH }
      OptionParser.new do |o|
        o.on("--file PATH", "Path to keywords JSON file") { |v| options[:file] = v }
        o.on("--hook", "Claude hook mode: read JSON from stdin, output hook JSON") { options[:hook] = true }
      end.parse!(argv)

      store = KeywordStore.new(options[:file])
      expander = Expander.new(store)

      if options[:hook]
        payload_json = $stdin.read
        payload = JSON.parse(payload_json)
        prompt = payload["prompt"].to_s
        found = expander.found_tokens(prompt)
        response = Formatter.hook_response(found)
        print response if response
      else
        text = argv[0]
        raise "Usage: expand-keyword expand --file PATH \"text with \$keywords\"" if text.nil?
        puts expander.expand(text)
      end
    end

    def usage
      <<~USAGE
        expand-keyword #{ExpandKeyword::VERSION}

        Usage: expand-keyword <subcommand> [options]

        Subcommands:
          list    [--file PATH]                          List all defined keywords
          add     [--file PATH] $TOKEN "expansion"      Add or update a keyword
                  [--description DESC]
          expand  [--file PATH] "text with $keywords"   Expand keywords in text
                  [--hook]                              Claude hook mode (reads JSON from stdin)

        Options:
          --version, -v   Show version
          --help, -h      Show this help
      USAGE
    end
  end
end
