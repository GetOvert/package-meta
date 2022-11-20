require "shellwords"

class Tap
  attr_reader :name

  def initialize(name)
    @name = name.sub(%r`/homebrew-`, '')
  end

  def install
    `brew tap #{@name.shellescape}`
  end

  def official?
    @official ||= JSON.parse(`brew tap-info --json=v1 #{@name.shellescape}`)[0]['official']
  end

  def cask_names
    @cask_names ||= `brew casks`
      .each_line(chomp: true)
      .select { |line| line.start_with?(@name) }
  end

  def to_s
    @name
  end
end
