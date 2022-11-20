#!/usr/bin/env ruby

require_relative "../cloud_storage.rb"
require_relative "../tap.rb"
require_relative "../cask.rb"
require "fileutils"
require "json"
require "pathname"
require "shellwords"

def dump_artifact_meta(tap)
  repo = `brew --repo #{tap.name}`.chomp
  unless File.directory? "#{repo}/.git"
    $stderr.puts "Skipped #{tap.name} at #{repo}"
    return
  end

  meta_file_name = "brew/#{tap.name}/artifact-meta.json"

  state = CloudStorage.download_json(meta_file_name) || {}

  artifact_meta = begin
    last_commit = state['commit']

    cask_names = if last_commit
      `#{__dir__}/changed_since_commit.sh #{repo} #{last_commit}`
        .lines(chomp: true)
    else
      tap.cask_names
      # For installed only:
      # `brew list --cask --full-name`.lines(chomp: true)
    end
    casks = cask_names.map { |name| Cask.new(name) }

    meta_by_name = Hash[
      casks.filter_map do |cask|
        meta = {}

        cask.with_installed do
          upload_cask_icon(cask)
          meta['copyright'] = cask_copyright_holders(cask)
        end

        [cask.name, meta]
      end
    ]

    {
      'cask': {
        **(state['by_name']&.[]('cask') || {}),
        **meta_by_name,
      },
    }
  end

  CloudStorage.upload_json(
    {
      'commit' => `git -C #{repo} rev-parse HEAD`.chomp,
      'by_name' => artifact_meta,
    },
    as: meta_file_name
  )
end

def upload_cask_icon(cask)
  cask.apps.find do |app|
    upload_app_icon app, as: "brew/#{cask.qualified_name}"
  end
end

def upload_app_icon(app, as:)
  file_name = "#{as}.png"

  return unless icns_path = app.icns_path

  Dir.mktmpdir do |tmpdir|
    png_path = File.join tmpdir, 'icon.png'
    `sips --setProperty format png --resampleHeightWidthMax 512 #{icns_path.shellescape} --out #{png_path.shellescape}`
    return unless $?.success?

    CloudStorage.upload_from_path png_path, as: file_name
  end
  true
end

def cask_copyright_holders(cask)
  cask.apps.filter_map { |app| app.copyright_holder }.join("; ")
end

if $0 == __FILE__
  abort "Usage: #{$0} <tap-name>" unless ARGV.length == 1

  dump_artifact_meta Tap.new(*ARGV)
end
