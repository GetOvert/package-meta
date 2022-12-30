#!/usr/bin/env ruby

require_relative "./../../cloud_storage.rb"
require_relative "../tap.rb"
require "fileutils"
require "json"
require "pathname"

def dump_update_times(tap)
  repo = `brew --repo #{tap.name.shellescape}`.chomp
  unless File.directory? "#{repo}/.git"
    $stderr.puts "Skipped #{tap.name} at #{repo}"
    return
  end

  update_times_file_name = "brew/#{tap.name}/update-times.json"

  state = CloudStorage.download_json(update_times_file_name) || {}

  update_times_by_name = begin
    last_commit = state['commit']
    tsv = if last_commit
      `#{__dir__}/from_commit.sh #{repo.shellescape} #{last_commit.shellescape}`
    else
      `#{__dir__}/all.sh #{repo.shellescape}`
    end

    new_update_times_by_name =
      tsv.lines(chomp: true)
        .group_by { |line| line.split("\t", 2)[0] }
        .transform_values do |lines|
          Hash[
            lines.map do |line|
              type, name, time = line.split "\t"

              # Prepend tap name for non-official taps
              name = "#{tap.name}/#{name}" unless tap.official?

              [name, time.to_i]
            end
          ]
        end

    {
      'formula': {
        **(state['by_name']&.[]('formula') || {}),
        **(new_update_times_by_name['formula'] || {}),
      },
      'cask': {
        **(state['by_name']&.[]('cask') || {}),
        **(new_update_times_by_name['cask'] || {}),
      },
    }
  end

  CloudStorage.upload_json(
    {
      'commit' => `git -C #{repo.shellescape} rev-parse HEAD`.chomp,
      'by_name' => update_times_by_name,
    },
    as: update_times_file_name
  )
end

if $0 == __FILE__
  abort "Usage: #{$0} <tap-name>" unless ARGV.length == 1

  dump_update_times Tap.new(*ARGV)
end
