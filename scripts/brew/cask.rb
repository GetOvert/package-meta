require_relative "./tap.rb"
require "json"
require "shellwords"

KiB = 1024
MiB = KiB**2
GiB = KiB**3
MAX_DOWNLOAD_SIZE = 6 * GiB

class Cask
  attr_reader :name

  def initialize(name)
    @name = name
  end

  def to_s
    @name
  end

  def info
    @info ||= JSON.parse(`brew info --json=v2 --cask #{@name.shellescape}`)&.dig('casks', 0)
  end

  def qualified_name
    if tap.official?
      "#{info['tap']}/#{info['token']}"
    else
      info['full_token']
    end
  end

  def tap
    @tap ||= Tap.new(info['tap'])
  end

  def with_installed
    # DISABLE THIS TO RUN LOCALLY
    # Change it to just `yield`

    $stderr.puts "Installing #{@name}"
    `brew install --cask --skip-cask-deps #{@name.shellescape}`
    begin
      if $?.success?
        yield
      else
        $stderr.puts "Failed to install #{@name}"
      end
    ensure
      $stderr.puts "Removing #{@name}"
      `brew uninstall --cask #{@name.shellescape}`
      `HOMEBREW_CLEANUP_MAX_AGE_DAYS=0 brew cleanup #{@name.shellescape}`
    end
  end

  def copyright_holder
    @copyright_holder ||= apps.filter_map(&:copyright_holder).join("; ")
  end

  def apps
    info['artifacts'].flat_map do |artifact|
      if app_file_names = artifact['app']

        Array(app_file_names).map do |app_file_name|
          File.join('/Applications', app_file_name)
        end

      elsif uninstall_items = artifact['uninstall']

        uninstall_items.flat_map do |uninstall_item|
          next unless pkg_identifiers = uninstall_item['pkgutil']

          Array(pkg_identifiers).flat_map do |pkg_identifier|
            app_paths_for_pkg_identifier(pkg_identifier)
          end
        end
      end
    end.compact.map { |app_path| App.new(app_path) }
  end

  private def app_paths_for_pkg_identifier(pkg_identifier)
    begin
      receipt_info = JSON.parse `pkgutil --pkg-info-plist #{pkg_identifier.shellescape} | plutil -convert json -o - -`
    rescue
      # No receipt? No problem
      return []
    end
    installation_base_path = File.join receipt_info['volume'], receipt_info['install-location']

    `pkgutil --only-dirs --files #{pkg_identifier.shellescape}`
      .lines(chomp: true)
      .filter { |subpath| subpath =~ /^[^\/]+\.app$/ }
      .map { |app_subpath| File.join(installation_base_path, app_subpath) }
  end
end

class App
  attr_reader :path

  def initialize(path)
    @path = path
  end

  def info
    @info ||= begin
      info_plist_path = File.join @path, 'Contents/Info.plist'

      json = `cat #{info_plist_path.shellescape} | plutil -convert json -o - -`
      JSON.parse json if $?.success?
    end
  end

  def icns_path
    return unless info and icon_file_name = info['CFBundleIconFile']

    icns_path = File.join @path, 'Contents/Resources', icon_file_name
    icns_path += '.icns' unless File.file? icns_path
    icns_path if File.file? icns_path
  end

  def copyright_holder
    return unless info and copyright = info['NSHumanReadableCopyright']

    copyright.gsub!(/\r?\n/, ' ')
    [
      # Collapse whitespace
      /\s+(?=\s)/i,
      # Remove "copyright" word/symbol
      /(copyright|©|\(c\))/i,
      # Remove years
      /\d{4}\s?[-–—]?\s?/i,
      # Remove irrelevant punctuation
      /(?<!co|corp|et al|lda|ltd|inc)\./i,
      /[,]/i,
      # Remove additional statements observed in the wild
      /\w+ rights reserved/i,
      /(licensed|released) under( \S+)* \S+/i,
    ].each do |r|
      copyright.gsub!(r, '')
    end
    copyright.strip!
    return if copyright.empty?

    copyright
  end
end
