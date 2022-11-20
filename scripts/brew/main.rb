#!/usr/bin/env ruby

require_relative "./tap.rb"
require_relative "./artifact-meta/dump.rb"
require_relative "./update-times/dump.rb"
require "parallel"
require "yaml"

MAX_PARALLEL = 16

abort "Usage: #{$0} <taps-yaml-file>" unless ARGV.length == 1

tap_items = YAML.load_file ARGV[0]
taps = tap_items.map { |item| Tap.new(item['name']) }

taps.each &:install
Parallel.each taps, in_threads: MAX_PARALLEL do |tap|
  dump_update_times tap
end
taps.each do |tap|
  dump_artifact_meta tap
end
