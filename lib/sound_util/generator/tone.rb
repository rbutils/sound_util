# frozen_string_literal: true

module SoundUtil
  module Generator
    module Tone
      DEFAULTS = {
        sample_rate: 44_100,
        channels: 1,
        amplitude: 1.0,
        phase: 0.0,
        format: :s16le
      }.freeze

      def sine(duration_seconds:, frequency:, **options)
        opts = DEFAULTS.merge(options)
        sample_rate = opts[:sample_rate]
        frames = (duration_seconds * sample_rate).to_i
        new(channels: opts[:channels], sample_rate: sample_rate, frames: frames, format: opts[:format]) do |frame_idx|
          t = frame_idx.to_f / sample_rate
          Math.sin((2.0 * Math::PI * frequency * t) + opts[:phase]) * opts[:amplitude]
        end
      end

      def silence(duration_seconds:, **options)
        opts = DEFAULTS.merge(options)
        sample_rate = opts[:sample_rate]
        frames = (duration_seconds * sample_rate).to_i
        new(channels: opts[:channels], sample_rate: sample_rate, frames: frames, format: opts[:format])
      end
    end
  end
end
