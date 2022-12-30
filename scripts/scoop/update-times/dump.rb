#!/usr/bin/env ruby

require_relative "../../cloud_storage.rb"
require_relative "../bucket.rb"
require "fileutils"
require "json"
require "pathname"

def dump_update_times(bucket)
  repo = bucket.repo_path
  unless File.directory? "#{repo}/.git"
    $stderr.puts "Skipped #{bucket} at #{repo}"
    return
  end

  update_times_file_name = "scoop/#{bucket.name}/update-times.json"

  state = CloudStorage.download_json(update_times_file_name) || {}

  update_times_by_name = begin
    last_commit = state['commit']
    tsv = if last_commit
      `sh #{__dir__}/from_commit.sh #{repo.shellescape} #{last_commit.shellescape}`
    else
      `sh #{__dir__}/all.sh #{repo.shellescape}`
    end

    new_update_times_by_name =
      tsv.lines(chomp: true)
        .group_by { |line| line.split("\t", 2)[0] }
        .transform_values do |lines|
          Hash[
            lines.map do |line|
              name, time = line.split "\t"

              # Prepend bucket name
              name = "#{bucket.name}/#{name}"

              [name, time.to_i]
            end
          ]
        end

    {
      'app': {
        **(state['by_name']&.[]('app') || {}),
        **(new_update_times_by_name['app'] || {}),
      }
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
  abort "Usage: #{$0} <bucket-name>" unless ARGV.length == 1

  dump_update_times Bucket.new(*ARGV)
end
