#!/usr/bin/env ruby

require_relative "../cloud_storage.rb"
require_relative "../bucket.rb"
require_relative "../app.rb"
require "fileutils"
require "json"
require "pathname"
require "shellwords"

BATCH_SIZE = 1

def dump_artifact_meta(bucket_config)
  bucket = bucket_config.bucket

  repo = bucket.repo_path
  unless File.directory? "#{repo}/.git"
    $stderr.puts "Skipped #{bucket} at #{repo}"
    return
  end

  meta_file_name = "scoop/#{bucket.name}/artifact-meta.json"

  state = CloudStorage.download_json(meta_file_name) || {}

  artifact_meta = begin
    last_commit = state['commit']

    app_names = if last_commit
      `sh #{__dir__}/changed_since_commit.sh #{repo} #{last_commit}`
        .lines(chomp: true)
    else
      bucket.app_names
    end

    all_apps = app_names.uniq.map { |name| App.new(name, bucket.name) }

    all_apps.filter! do |app|
      should_download = bucket_config.should_download?(app)
      $stderr.puts "Skipping download for #{app}" unless should_download
      should_download
    end

    meta_by_name = {}
    all_apps.each_with_index.each_slice(BATCH_SIZE) do |batch|
      apps, indices = batch.transpose

      $stderr.puts "\n(#{indices.first + 1}–#{indices.last + 1}/#{all_apps.count}) #{apps.join(', ')}"

      App.with_all_installed(apps) do
        apps.each do |app|
          if bucket_config.should_harvest_icon?(app)
            upload_app_icon(app)
          else
            $stderr.puts "Skipping icon harvest for #{app} (publisher: #{app.publisher})"
          end

          meta_by_name[app.qualified_name] = {
            'official_name': app.official_name,
            'product_name': app.product_name,
            'copyright': app.copyright,
            'trademarks': app.trademarks,
            'publisher': app.publisher
          }
        end
      end

    rescue => e
      $stderr.puts "Error dumping artifact meta for #{apps.join(', ')}: #{e}"
    end

    {
      'app': {
        **(state['by_name']&.[]('app') || {}),
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

def upload_app_icon(app)
  app.executables.find do |executable|
    upload_executable_icon executable, as: "scoop/#{app.qualified_name}"
  end
end

def upload_executable_icon(executable, as:)
  return unless icon_path = executable.extract_icon

  CloudStorage.upload_from_path icon_path, as: "#{as}.png"
  true
end

if $0 == __FILE__
  abort "Usage: #{$0} <bucket-name>" unless ARGV.length == 1

  dump_artifact_meta BucketConfig.new(Bucket.new(*ARGV))
end
