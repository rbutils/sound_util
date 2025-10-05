# frozen_string_literal: true

module SoundUtil
  module Filter
    module Resample
      extend Filter::Mixin

      define_immutable_version :resample

      def resample!(new_sample_rate, frames: nil, method: :linear)
        target_rate = Integer(new_sample_rate)
        raise ArgumentError, "new sample rate must be positive" unless target_rate.positive?

        target_frames = frames ? Integer(frames) : calculate_target_frames(target_rate)
        raise ArgumentError, "target frames must be positive" unless target_frames.positive?

        return self if target_rate == sample_rate && target_frames == self.frames

        case method
        when :linear
          perform_linear_resample!(target_rate, target_frames)
        else
          raise ArgumentError, "unsupported resample method: #{method.inspect}"
        end

        self
      end

      private

      def calculate_target_frames(new_sample_rate)
        frames = (duration * new_sample_rate).round
        frames = 1 if frames.zero?
        frames
      end

      def perform_linear_resample!(target_rate, target_frames)
        if frames.zero?
          initialize_from_buffer(Util.build_buffer(self, channels: channels, frames: target_frames, sample_rate: target_rate))
          @sample_rate = target_rate
          @frames = target_frames
          return
        end

        ratio = sample_rate.to_f / target_rate
        new_buffer = Util.build_buffer(self, channels: channels, frames: target_frames, sample_rate: target_rate)

        target_frames.times do |frame_idx|
          source_position = frame_idx * ratio
          left_idx = source_position.floor
          right_idx = [left_idx + 1, frames - 1].min
          t = source_position - left_idx

          left_frame = buffer.read_frame(left_idx)
          right_frame = buffer.read_frame(right_idx)

          samples = Array.new(channels) do |channel_idx|
            left = sample_to_float(left_frame[channel_idx])
            right = sample_to_float(right_frame[channel_idx])
            value = if left_idx == right_idx
                      left
                    else
                      left + (right - left) * t
                    end
            encode_value(value)
          end

          new_buffer.write_frame(frame_idx, samples)
        end

        initialize_from_buffer(new_buffer)
        @sample_rate = target_rate
        @frames = target_frames
      end
    end
  end
end
