# frozen_string_literal: true

module SoundUtil
  module Filter
    module Combine
      def append(other_wave)
        self.class.generate_appended_wave(left: self, right: other_wave)
      end

      def append!(other_wave)
        wave = append(other_wave)
        initialize_from_buffer(wave.buffer)
        self
      end

      def mix(other_wave)
        self.class.generate_mixed_wave(left: self, right: other_wave)
      end

      def mix!(other_wave)
        wave = mix(other_wave)
        initialize_from_buffer(wave.buffer)
        self
      end

      def stack_channels(other_wave)
        self.class.generate_stacked_wave(primary: self, secondary: other_wave)
      end

      def stack_channels!(other_wave)
        wave = stack_channels(other_wave)
        initialize_from_buffer(wave.buffer)
        self
      end

      alias + append
      alias << append!
      alias | mix
      alias & stack_channels
    end
  end
end
