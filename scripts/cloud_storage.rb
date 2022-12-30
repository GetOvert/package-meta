require_relative "./env.rb"
require "google/cloud/storage"

module CloudStorage
  BUCKET = Google::Cloud::Storage.new.bucket 'storage.getovert.app'

  module_function

  def download_json file_name
    io = BUCKET.file(file_name)&.download
    return if io.nil?

    io.rewind
    JSON.load io
  end

  def upload_json new_contents, as:
    file_name = as

    new_json = JSON.generate new_contents

    BUCKET.upload_file StringIO.new(new_json), file_name

    post_upload file_name
  end

  def upload_from_path source_path, as:
    file_name = as

    File.open source_path do |source_file|
      BUCKET.upload_file source_file, file_name
    end

    post_upload file_name
  end

  private def post_upload file_name
    BUCKET.file(file_name).cache_control = 'public, max-age=600'

    $stderr.puts "Uploaded as #{file_name}"
  end
end
