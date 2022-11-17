require_relative "../env.rb"
require "google/cloud/storage"

class Tap
  BUCKET = Google::Cloud::Storage.new.bucket 'storage.getovert.app'

  attr_reader :name

  def official?; @official; end

  def initialize(name)
    @name = name
    @official = JSON.parse(`brew tap-info --json=v1 #{@name}`)[0]['official']
  end

  def install
    `brew tap #{@name}`
  end
end
