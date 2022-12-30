#!/usr/bin/env ruby

require_relative "./bucket.rb"
require_relative "./artifact-meta/dump.rb"
require_relative "./update-times/dump.rb"
require "parallel"
require "yaml"

MAX_PARALLEL = 32

abort "Usage: #{$0} <buckets-yaml-file>" unless ARGV.length == 1

bucket_items = YAML.load_file ARGV[0]
bucket_configs = bucket_items.map do |item|
  BucketConfig.new(
    Bucket.new(item['name'], item['url']),
    skip_download: BucketConfigSkipDownload.new(item['skip_download']),
    skip_icon_harvest: BucketConfigSkipIconHarvest.new(item['skip_icon_harvest'])
  )
end
buckets = bucket_config.map &:bucket

Parallel.each buckets, in_threads: MAX_PARALLEL do |bucket|
  bucket.install
end
Parallel.each buckets, in_threads: MAX_PARALLEL do |bucket|
  $stderr.puts "Dumping update times for #{bucket}"
  dump_update_times bucket
end
bucket_configs.each do |bucket_config|
  $stderr.puts "Dumping artifact meta for #{bucket_config.bucket}"
  dump_artifact_meta bucket_config
end
