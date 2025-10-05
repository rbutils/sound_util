# frozen_string_literal: true

require_relative "sound_util/version"

module SoundUtil
  class Error < StandardError; end

  autoload :CLI, "sound_util/cli"
  autoload :Codec, "sound_util/codec"
  autoload :Filter, "sound_util/filter"
  autoload :Generator, "sound_util/generator"
  autoload :Magic, "sound_util/magic"
  autoload :Sink, "sound_util/sink"
  autoload :Wave, "sound_util/wave"
end
