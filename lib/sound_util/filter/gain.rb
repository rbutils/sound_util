# frozen_string_literal: true

module SoundUtil
  module Filter
    module Gain
      extend Filter::Mixin

      define_immutable_version :gain

      def gain!(factor)
        mutate_frames! do |_frame_idx, samples|
          samples.map { |sample| encode_value(sample_to_float(sample) * factor) }
        end
      end

      alias * gain
    end
  end
end
