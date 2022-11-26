require "forwardable"
require "shellwords"

class Tap
  attr_reader :name

  def initialize(name)
    @name = name.sub(%r`/homebrew-`, '')
  end

  def to_s
    @name
  end

  def install
    `brew tap #{@name.shellescape}`
  end

  def official?
    @official ||= JSON.parse(`brew tap-info --json=v1 #{@name.shellescape}`)[0]['official']
  end

  def cask_names
    @cask_names ||= `brew casks`
      .each_line(chomp: true)
      .select { |line| line.start_with?(@name) }
  end
end

class TapConfig
  extend Forwardable

  attr_reader :tap, :skip_download, :skip_icon_harvest

  def initialize(tap, skip_download: nil, skip_icon_harvest: nil)
    @tap = tap
    @skip_download = skip_download
    @skip_icon_harvest = skip_icon_harvest
  end

  def_delegator :skip_download, :should_download?
  def_delegator :skip_icon_harvest, :should_harvest_icon?
end

class TapConfigSkipDownload
  def initialize(config)
    config ||= []
    @name_patterns = config.filter_map { |item| Regexp.new(item['name']) if item['name'] }
  end

  def should_download?(cask)
    none_match?(@name_patterns, cask.name)
  end
end

class TapConfigSkipIconHarvest
  def initialize(config)
    config ||= []
    @name_patterns = config.filter_map { |item| Regexp.new(item['name']) if item['name'] }
    @copyright_patterns = config.filter_map { |item| Regexp.new(item['copyright']) if item['copyright'] }
  end

  def should_harvest_icon?(cask)
    none_match?(@name_patterns, cask.name) &&
      none_match(@copyright_patterns, cask.copyright_holder)
  end
end

def none_match?(patterns, subject)
  patterns.none? { |pattern| subject =~ pattern }
end
