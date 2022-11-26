#!/usr/bin/env ruby

require_relative "../cloud_storage.rb"
require_relative "../tap.rb"
require_relative "../cask.rb"
require "fileutils"
require "json"
require "pathname"
require "shellwords"

BATCH_SIZE = 16

def dump_artifact_meta(tap_config)
  tap = tap_config.tap

  repo = `brew --repo #{tap.name}`.chomp
  unless File.directory? "#{repo}/.git"
    $stderr.puts "Skipped #{tap} at #{repo}"
    return
  end

  meta_file_name = "brew/#{tap.name}/artifact-meta.json"

  state = CloudStorage.download_json(meta_file_name) || {}

  artifact_meta = begin
    last_commit = state['commit']

    cask_names = if last_commit
      `#{__dir__}/changed_since_commit.sh #{repo} #{last_commit}`
        .lines(chomp: true)
        .map do |short_name|
          # To match the output of `tap.cask_names` (`brew casks`), only prepend
          # tap name for non-official taps
          # This allows consistent filtering on these generated names
          # for skip_{download,icon_harvest}
          tap.official? ? short_name : "#{tap.name}/#{short_name}"
        end
    else
      tap.cask_names
      # For installed only:
      # `brew list --cask --full-name`.lines(chomp: true)
    end

    all_casks = cask_names.uniq.map { |name| Cask.new(name) }

    all_casks.filter! do |cask|
      should_download = tap_config.should_download?(cask)
      $stderr.puts "Skipping download for #{cask}" unless should_download
      should_download
    end

    meta_by_name = {}
    all_casks.each_with_index.each_slice(BATCH_SIZE) do |batch|
      casks, indices = batch.transpose

      $stderr.puts "\n(#{indices.first + 1}–#{indices.last + 1}/#{casks.count}) #{casks.join(', ')}"

      meta = {}
      Cask.with_all_installed(casks) do
        casks.each do |cask|
          if tap_config.should_harvest_icon?(cask)
            upload_cask_icon(cask)
          else
            $stderr.puts "Skipping icon harvest for #{cask} (publisher: #{cask.publisher})"
          end

          meta['copyright'] = cask.copyright
          meta['publisher'] = cask.publisher
        end
      end

      meta_by_name[cask.info.full_name] = meta
    rescue => e
      $stderr.puts "Error dumping artifact meta for #{casks.join(', ')}: #{e}"
    end

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

if $0 == __FILE__
  abort "Usage: #{$0} <tap-name>" unless ARGV.length == 1

  dump_artifact_meta TapConfig.new(Tap.new(*ARGV))
end
