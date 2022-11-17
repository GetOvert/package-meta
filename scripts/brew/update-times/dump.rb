#!/usr/bin/env ruby

require_relative "../tap.rb"
require "fileutils"
require "json"
require "pathname"

class Tap
  def dump_update_times
    repo = `brew --repo #{@name}`.chomp
    unless File.directory? "#{repo}/.git"
      $stderr.puts "Skipped #{@name} at #{repo}"
      return
    end

    state = load_state || {}

    update_times_by_name = begin
      last_commit = state['commit']
      tsv = if last_commit
        `#{__dir__}/from_commit.sh #{repo} #{last_commit}`
      else
        `#{__dir__}/all.sh #{repo}`
      end

      new_update_times_by_name =
        tsv.lines(chomp: true)
          .group_by { |line| line.split("\t", 2)[0] }
          .transform_values do |lines|
            Hash[
              lines.map do |line|
                type, name, time = line.split "\t"

                # Prepend tap name for non-official taps
                name = "#{@name}/#{name}" unless official?

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

    save_state({
      'commit' => `git -C #{repo} rev-parse HEAD`.chomp,
      'by_name' => update_times_by_name,
    })
  end

  private def load_state
    io = BUCKET.file(state_file_name)&.download
    return if io.nil?

    io.rewind
    JSON.load io
  end

  private def save_state(new_state)
    state_json = JSON.generate new_state

    BUCKET.upload_file StringIO.new(state_json), state_file_name
    BUCKET.file(state_file_name).cache_control = 'public, max-age=600'

    $stderr.puts "Uploaded as #{state_file_name}"
  end

  private def state_file_name
    "brew/#{@name}/update-times.json"
  end
end

if $0 == __FILE__
  abort "Usage: #{$0} <tap-name>" unless ARGV.length == 1

  Tap.new(*ARGV).dump_update_times_by_name
end
