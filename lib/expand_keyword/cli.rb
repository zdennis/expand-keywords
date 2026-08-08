require "optparse"
require "json"
require "fileutils"
require_relative "version"
require_relative "config"
require_relative "keyword_store"
require_relative "expander"
require_relative "formatter"

module ExpandKeyword
  class CLI
    def run(argv)
      argv = argv.dup
      subcommand = argv.shift

      case subcommand
      when "init"
        run_init(argv)
      when "config"
        run_config(argv)
      when "list"
        run_list(argv)
      when "add"
        run_add(argv)
      when "remove"
        run_remove(argv)
      when "expand"
        run_expand(argv)
      when "edit"
        run_edit(argv)
      when "doctor"
        run_doctor(argv)
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

    def run_init(argv)
      options = {}
      OptionParser.new do |o|
        o.on("--config PATH", "Path to config file") { |v| options[:config] = v }
        o.on("--file PATH", "Path to keywords JSON file") { |v| options[:file] = v }
      end.parse!(argv)

      config = options[:config] ? Config.new(options[:config]) : Config.new
      keywords_path = options[:file] || config.keywords_path

      puts "Initializing expand-keyword configuration..."
      puts ""

      if config.create!
        puts "  Created config file: #{config.path}"
      else
        puts "  Config file already exists: #{config.path}"
      end

      if File.exist?(keywords_path)
        puts "  Keywords file already exists: #{keywords_path}"
      else
        store = KeywordStore.new(keywords_path)
        FileUtils.mkdir_p(File.dirname(keywords_path))
        store.save
        puts "  Created keywords file: #{keywords_path}"
      end

      puts ""
      puts "Done. Add keywords with: expand-keyword add '$name' 'expansion text'"
    end

    def run_config(argv)
      options = {}
      OptionParser.new do |o|
        o.on("--config PATH", "Path to config file") { |v| options[:config] = v }
      end.parse!(argv)

      config = options[:config] ? Config.new(options[:config]) : Config.new

      puts "Config file: #{config.path}"
      puts "Keywords file: #{config.keywords_path}"
      puts ""
      puts config.to_s
    end

    def run_list(argv)
      options = { file: KeywordStore.default_path }
      OptionParser.new do |o|
        o.on("--file PATH", "Path to keywords JSON file") { |v| options[:file] = v }
      end.parse!(argv)

      store = KeywordStore.new(options[:file])
      puts Formatter.list(store.all)
    end

    def run_add(argv)
      options = { file: KeywordStore.default_path }
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

    def run_remove(argv)
      options = { file: KeywordStore.default_path }
      OptionParser.new do |o|
        o.on("--file PATH", "Path to keywords JSON file") { |v| options[:file] = v }
      end.parse!(argv)

      token = argv[0]
      raise "Usage: expand-keyword remove \$TOKEN" if token.nil?

      store = KeywordStore.new(options[:file])
      if store.delete(token)
        puts "Removed #{token}"
      else
        warn "Token not found: #{token}"
        exit 1
      end
    end

    def run_expand(argv)
      options = { file: KeywordStore.default_path }
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

    def run_edit(argv)
      options = { file: KeywordStore.default_path }
      OptionParser.new do |o|
        o.on("--file PATH", "Path to keywords JSON file") { |v| options[:file] = v }
      end.parse!(argv)

      editor = ENV["VISUAL"] || ENV["EDITOR"] || "vi"
      store = KeywordStore.new(options[:file])

      FileUtils.mkdir_p(File.dirname(store.path))
      unless File.exist?(store.path)
        store.save
        puts "Created #{store.path}"
      end

      exec(editor, store.path)
    end

    def run_doctor(argv)
      options = {}
      OptionParser.new do |o|
        o.on("--config PATH", "Path to config file") { |v| options[:config] = v }
      end.parse!(argv)

      config = options[:config] ? Config.new(options[:config]) : Config.new
      keywords_path = KeywordStore.default_path
      binary = File.expand_path("../../../bin/expand-keyword", __FILE__)
      passed = true

      puts "expand-keyword doctor"
      puts ""

      # Check binary in PATH
      binary_in_path = system("which expand-keyword > /dev/null 2>&1")
      if binary_in_path
        resolved = `which expand-keyword`.strip
        puts "  [OK] binary in PATH: #{resolved}"
      else
        puts "  [FAIL] expand-keyword not found in PATH"
        puts "         Fix: ln -s #{binary} /usr/local/bin/expand-keyword"
        passed = false
      end

      # Check config file
      if config.exists?
        puts "  [OK] config file: #{config.path}"
      else
        puts "  [WARN] config file not found: #{config.path}"
        puts "         Fix: expand-keyword init"
      end

      # Check keywords file
      if File.exist?(keywords_path)
        begin
          JSON.parse(File.read(keywords_path))
          count = KeywordStore.new(keywords_path).all.size
          puts "  [OK] keywords file: #{keywords_path} (#{count} keyword#{"s" if count != 1})"
        rescue JSON::ParserError => e
          puts "  [FAIL] keywords file has invalid JSON: #{keywords_path}"
          puts "         Error: #{e.message}"
          passed = false
        end
      else
        puts "  [WARN] keywords file not found: #{keywords_path}"
        puts "         Fix: expand-keyword init"
      end

      # Check Claude settings.json for hook registration
      claude_settings = File.expand_path("~/.claude/settings.json")
      if File.exist?(claude_settings)
        content = File.read(claude_settings)
        if content.include?("expand-keyword") && content.include?("UserPromptSubmit")
          puts "  [OK] Claude Code hook registered in #{claude_settings}"
        else
          puts "  [WARN] expand-keyword hook not found in #{claude_settings}"
          puts "         See README for hook setup instructions"
        end
      else
        puts "  [WARN] Claude settings not found: #{claude_settings}"
        puts "         See README for hook setup instructions"
      end

      puts ""
      if passed
        puts "All checks passed."
      else
        puts "Some checks failed. See above for fixes."
        exit 1
      end
    end

    def usage
      <<~USAGE
        expand-keyword #{ExpandKeyword::VERSION}

        Usage: expand-keyword <subcommand> [options]

        Subcommands:
          init    [--config PATH]                        Initialize config and keywords file
          config  [--config PATH]                        Show config path and contents
          list    [--file PATH]                          List all defined keywords
          add     [--file PATH] $TOKEN "expansion"       Add or update a keyword
                  [--description DESC]
          remove  [--file PATH] $TOKEN                   Remove a keyword
          expand  [--file PATH] "text with $keywords"    Expand keywords in text
                  [--hook]                               Claude hook mode (reads JSON from stdin)
          edit    [--file PATH]                          Open keywords file in $EDITOR
          doctor  [--config PATH]                        Check setup and configuration

        Options:
          --version, -v   Show version
          --help, -h      Show this help

        Environment:
          EXPAND_KEYWORD_FILE   Override the keywords file path
          XDG_CONFIG_HOME       Override the config base directory (default: ~/.config)
          VISUAL / EDITOR       Editor used by the edit subcommand
      USAGE
    end
  end
end
