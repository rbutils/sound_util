# frozen_string_literal: true

module SoundUtil
  module Filter
    module Gain
      extend Filter::Mixin

      define_immutable_version :gain

      def gain!(factor)
        info = format_info
        mutate_frames! do |_frame_idx, samples|
          samples.map { |sample| scale_sample(sample, factor, info) }
        end
      end

      alias * gain

      private

      def scale_sample(sample, factor, info)
        (sample * factor).round.clamp(info[:min], info[:max])
      end
    end
  end
end
