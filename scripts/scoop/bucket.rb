require "forwardable"
require "shellwords"

class Bucket
  attr_reader :name

  def initialize(name, url)
    @name = name
    @url = url
  end

  def to_s
    @name
  end

  def repo_path
    File.join(Dir.home, 'scoop', 'buckets', @name)
  end

  def install
    `scoop bucket add #{@name.shellescape} #{@url.shellescape}`
  end

  def official?
    @official ||= `scoop bucket known`.chomp.split(/\r?\n/).include?(@name)
  end

  def app_names
    @app_names ||= Dir.glob('*.json', base: File.join(repo_path, 'bucket'))
      .map { |file_name| File.basename(file_name, '.json') }
  end
end

class BucketConfig
  extend Forwardable

  attr_reader :bucket, :skip_download, :skip_icon_harvest

  def initialize(bucket, skip_download: nil, skip_icon_harvest: nil)
    @bucket = bucket
    @skip_download = skip_download
    @skip_icon_harvest = skip_icon_harvest
  end

  def_delegator :skip_download, :should_download?
  def_delegator :skip_icon_harvest, :should_harvest_icon?
end

class BucketConfigSkipDownload
  def initialize(config)
    config ||= []
    @name_patterns = config.filter_map { |item| Regexp.new(item['name']) if item['name'] }
  end

  def should_download?(app)
    none_match?(@name_patterns, app.name)
  end
end

class BucketConfigSkipIconHarvest
  def initialize(config)
    config ||= []
    @name_patterns = config.filter_map { |item| Regexp.new(item['name']) if item['name'] }
  end

  def should_harvest_icon?(app)
    none_match?(@name_patterns, app.name)
  end
end

def none_match?(patterns, subject)
  patterns.none? { |pattern| subject =~ pattern }
end
