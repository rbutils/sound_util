# frozen_string_literal: true

module SoundUtil
  module Generator
    module Combine
      def generate_appended_wave(left:, right:)
        Util.ensure_same_kind!(left, right)
        Util.assert_dimensions!(right, channels: left.channels)

        buffer = build_appended_buffer(left, right)
        Util.build_wave_from_buffer(left, buffer)
      end

      def generate_mixed_wave(left:, right:)
        Util.ensure_same_kind!(left, right)
        Util.assert_dimensions!(right, channels: left.channels)

        frames = [left.frames, right.frames].max
        buffer = Util.build_buffer(left, channels: left.channels, frames: frames)

        info = left.format_info
        zero = Util.zero_frame(left.channels)

        frames.times do |frame_idx|
          left_frame = frame_idx < left.frames ? left.buffer.read_frame(frame_idx) : zero
          right_frame = frame_idx < right.frames ? right.buffer.read_frame(frame_idx) : zero

          samples = Array.new(buffer.channels) do |channel_idx|
            mix_sample(left_frame[channel_idx], right_frame[channel_idx], info)
          end

          buffer.write_frame(frame_idx, samples)
        end

        Util.build_wave_from_buffer(left, buffer)
      end

      def generate_stacked_wave(primary:, secondary:)
        Util.ensure_same_kind!(primary, secondary)

        frames = [primary.frames, secondary.frames].max
        total_channels = primary.channels + secondary.channels

        buffer = Util.build_buffer(primary, channels: total_channels, frames: frames)

        primary_zero = Util.zero_frame(primary.channels)
        secondary_zero = Util.zero_frame(secondary.channels)

        frames.times do |frame_idx|
          primary_frame = frame_idx < primary.frames ? primary.buffer.read_frame(frame_idx) : primary_zero
          secondary_frame = frame_idx < secondary.frames ? secondary.buffer.read_frame(frame_idx) : secondary_zero

          buffer.write_frame(frame_idx, primary_frame + secondary_frame)
        end

        Util.build_wave_from_buffer(primary, buffer)
      end

      private

      def build_appended_buffer(left, right)
        buffer = Util.build_buffer(left, channels: left.channels, frames: left.frames + right.frames)

        destination = buffer.io_buffer
        destination.copy(left.buffer.io_buffer, 0)
        destination.copy(right.buffer.io_buffer, left.buffer.size)
        buffer
      end

      def mix_sample(first, second, info)
        (first + second).clamp(info[:min], info[:max])
      end
    end
  end
end
