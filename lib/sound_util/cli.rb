# frozen_string_literal: true

require "thor"

module SoundUtil
  class CLI < Thor
    desc "version", "Display SoundUtil version"
    def version
      puts SoundUtil::VERSION
    end
  end
end
