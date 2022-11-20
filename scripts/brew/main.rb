#!/usr/bin/env ruby

require_relative "./tap.rb"
require_relative "./artifact-meta/dump.rb"
require_relative "./update-times/dump.rb"
require "parallel"
require "yaml"

MAX_PARALLEL = 16

abort "Usage: #{$0} <taps-yaml-file>" unless ARGV.length == 1

tap_items = YAML.load_file ARGV[0]
tap_configs = tap_items.map do |item|
  TapConfig.new(
    Tap.new(item['name']),
    skip_download: TapConfigSkipDownload.new(item['skip_download']),
    skip_icon_harvest: TapConfigSkipIconHarvest.new(item['skip_icon_harvest'])
  )
end
taps = tap_configs.map &:tap

Parallel.each taps, in_threads: MAX_PARALLEL do |tap|
  tap.install
end
Parallel.each taps, in_threads: MAX_PARALLEL do |tap|
  $stderr.puts "Dumping update times for #{tap}"
  dump_update_times tap
end
tap_configs.each do |tap_config|
  $stderr.puts "Dumping artifact meta for #{tap_config.tap}"
  dump_artifact_meta tap_config
end
