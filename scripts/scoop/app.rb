require_relative "./bucket.rb"
require "json"
require "shellwords"

KiB = 1024
MiB = KiB**2
GiB = KiB**3
MAX_DOWNLOAD_SIZE = 6 * GiB

class App
  attr_reader :name, :bucket_name

  def initialize(name, bucket_name)
    @name = name
    @bucket_name = bucket_name
  end

  def to_s
    @name
  end

  def info
    @info ||= begin
      File.open(File.join(Dir.home, 'scoop', 'buckets', @bucket_name, 'bucket', "#{@name}.json")) do |io|
        JSON.load io
      end
    end
  end

  def qualified_name
    "#{@bucket_name}/#{@name}"
  end

  def bucket
    @bucket ||= Bucket.new(@bucket_name)
  end

  def with_installed
    $stderr.puts "Installing #{qualified_name}"
    `scoop install #{qualified_name.shellescape}`
    return $stderr.puts "Failed to install #{qualified_name}" unless $?.success?

    begin
      yield
    ensure
      $stderr.puts "Removing #{qualified_name}"
      `scoop uninstall #{qualified_name.shellescape}`
      `scoop cleanup --all --cache`
    end
  end

  def self.with_all_installed(apps)
    # DISABLE THIS TO RUN LOCALLY
    # Change it to just `yield`

    app_args = apps.map(&:name).map(&:shellescape).join(' ')

    $stderr.puts "Installing #{app_args}"
    `scoop install #{app_args}`
    return $stderr.puts "Failed to install #{app_args}" unless $?.success?

    begin
      yield
    ensure
      $stderr.puts "Removing #{app_args}"
      `scoop uninstall #{app_args}`
      `scoop cleanup --all --cache`
    end
  end

  def official_name
    @official_name ||= executables.filter_map(&:official_name).join("; ")
  end

  def product_name
    @product_name ||= executables.filter_map(&:product_name).join("; ")
  end

  def copyright
    @copyright ||= executables.filter_map(&:copyright).join("; ")
  end

  def trademarks
    @trademarks ||= executables.filter_map(&:trademarks).join("; ")
  end

  def publisher
    @publisher ||= executables.filter_map(&:publisher).join("; ")
  end

  def executables
    Array(info['bin']).map { |executable_name| Executable.new(@name, executable_name) }
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

class Executable
  attr_reader :app_name, :executable_file_name

  def initialize(app_name, app_executable_name)
    @app_name = app_name
    @app_executable_name = app_executable_name
  end

  def official_name
    @official_name ||= read_extended_property 'System.FileDescription'
  end

  def product_name
    @product_name ||= read_extended_property 'System.Software.ProductName'
  end

  def copyright
    @copyright ||= read_extended_property 'System.Copyright'
  end

  def trademarks
    @trademarks ||= read_extended_property 'System.Trademarks'
  end

  def publisher
    return unless publisher = copyright

    publisher.gsub!(/\r?\n/, ' ')
    [
      # Collapse whitespace
      /\s+(?=\s)/i,
      # Remove "copyright" word/symbol
      /(copyright|©|\(c\))/i,
      # Remove years
      /\d{4}\s?[-–—]?\s?/i,
      # Remove irrelevant punctuation
      /(?<!co|corp|et al|lda|ltd|inc)\.(?!com)/i,
      /[,]/i,
      # Remove additional statements observed in the wild
      /\w+ rights reserved\b/i,
      /\b(licensed|released) under( \S+)* \S+/i,
      /\b[AL]GPL\s*v?\d?\s*\+?\b/i,
      /\bPLACEHOLDER FOR LOCALIZATION\b/i,
      /\bThis software is\b/i,
    ].each do |r|
      publisher.gsub!(r, '')
    end
    publisher.strip!
    return if publisher.empty?

    publisher
  end

  # https://github.com/EddieRingle/portaudio/blob/master/src/hostapi/wasapi/mingw-include/propkey.h
  private def read_extended_property(property_key)
    value = %x{
      powershell.exe #{__dir__}/read_extended_property.ps1 -AppName #{@app_name} -AppExecutableName #{@app_executable_name} -ExtendedPropertyName #{property_key}
    }
    unless $?.success?
      $stderr.print value
      return
    end

    value.chomp
  end

  def extract_icon
    path = %x{
      powershell.exe #{__dir__}/extract_icon.ps1 -AppName #{@app_name} -AppExecutableName #{@app_executable_name}
    }
    unless $?.success?
      $stderr.print path
      return
    end

    path.chomp
  end
end
