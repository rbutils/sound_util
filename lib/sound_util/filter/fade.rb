# frozen_string_literal: true

module SoundUtil
  module Filter
    module Fade
      extend Filter::Mixin

      define_immutable_version :fade_in, :fade_out

      def fade_in!(seconds: duration)
        apply_fade!(seconds, :in)
      end

      def fade_out!(seconds: duration)
        apply_fade!(seconds, :out)
      end

      private

      def apply_fade!(seconds, direction)
        fade_frames = (seconds * sample_rate).to_i
        fade_frames = [[fade_frames, 1].max, frames].min
        info = format_info

        mutate_frames! do |frame_idx, samples|
          factor = fade_factor(frame_idx, fade_frames, direction)
          samples.map { |sample| scale_sample(sample, factor, info) }
        end
      end

      def fade_factor(frame_idx, fade_frames, direction)
        case direction
        when :in
          return 1.0 if frame_idx >= fade_frames

          (frame_idx + 1).to_f / fade_frames
        when :out
          remaining = frames - frame_idx
          return 1.0 if remaining > fade_frames

          [(remaining - 1), 0].max.to_f / fade_frames
        else
          1.0
        end
      end

      def scale_sample(sample, factor, info)
        (sample * factor).round.clamp(info[:min], info[:max])
      end
    end
  end
end
