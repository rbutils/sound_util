# frozen_string_literal: true

require_relative "sound_util/version"

module SoundUtil
  class Error < StandardError; end

  autoload :CLI, "sound_util/cli"
end
