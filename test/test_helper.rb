require "minitest/autorun"
require "tmpdir"
require "json"
require "stringio"
require "fileutils"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

module TestHelpers
  def with_keyword_file(data)
    dir = Dir.mktmpdir
    path = File.join(dir, "expand-keywords.json")
    File.write(path, JSON.generate(data))
    yield path
  ensure
    FileUtils.rm_rf(dir)
  end

  def empty_keyword_file
    dir = Dir.mktmpdir
    path = File.join(dir, "expand-keywords.json")
    # don't create it — testing "file does not exist" case
    yield path
  ensure
    FileUtils.rm_rf(dir)
  end
end
