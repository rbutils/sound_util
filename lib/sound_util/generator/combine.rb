# frozen_string_literal: true

module SoundUtil
  module Generator
    module Combine
      def generate_appended_wave(left:, right:)
        ensure_wave_type!(left, right)
        ensure_common_format!(left, right)
        ensure_same_channels!(left, right)

        buffer = build_appended_buffer(left, right)
        build_wave_from_buffer(left, buffer)
      end

      def generate_mixed_wave(left:, right:)
        ensure_wave_type!(left, right)
        ensure_common_format!(left, right)
        ensure_same_channels!(left, right)

        frames = [left.frames, right.frames].max
        buffer = left.class::Buffer.new(
          channels: left.channels,
          sample_rate: left.sample_rate,
          frames: frames,
          format: left.format
        )

        info = left.format_info
        zero = Array.new(left.channels, 0)

        frames.times do |frame_idx|
          left_frame = frame_idx < left.frames ? left.buffer.read_frame(frame_idx) : zero
          right_frame = frame_idx < right.frames ? right.buffer.read_frame(frame_idx) : zero

          samples = Array.new(buffer.channels) do |channel_idx|
            mix_sample(left_frame[channel_idx], right_frame[channel_idx], info)
          end

          buffer.write_frame(frame_idx, samples)
        end

        build_wave_from_buffer(left, buffer)
      end

      def generate_stacked_wave(primary:, secondary:)
        ensure_wave_type!(primary, secondary)
        ensure_common_format!(primary, secondary)

        frames = [primary.frames, secondary.frames].max
        total_channels = primary.channels + secondary.channels

        buffer = primary.class::Buffer.new(
          channels: total_channels,
          sample_rate: primary.sample_rate,
          frames: frames,
          format: primary.format
        )

        primary_zero = Array.new(primary.channels, 0)
        secondary_zero = Array.new(secondary.channels, 0)

        frames.times do |frame_idx|
          primary_frame = frame_idx < primary.frames ? primary.buffer.read_frame(frame_idx) : primary_zero
          secondary_frame = frame_idx < secondary.frames ? secondary.buffer.read_frame(frame_idx) : secondary_zero

          buffer.write_frame(frame_idx, primary_frame + secondary_frame)
        end

        build_wave_from_buffer(primary, buffer)
      end

      private

      def ensure_wave_type!(reference, other)
        return if other.is_a?(reference.class)

        raise ArgumentError, "expected wave of type #{reference.class}, got #{other.class}"
      end

      def ensure_common_format!(left, right)
        return if left.sample_rate == right.sample_rate && left.format == right.format

        raise ArgumentError, "waves must share sample rate and format"
      end

      def ensure_same_channels!(left, right)
        return if left.channels == right.channels

        raise ArgumentError, "waves must have the same channel count"
      end

      def build_appended_buffer(left, right)
        buffer = left.class::Buffer.new(
          channels: left.channels,
          sample_rate: left.sample_rate,
          frames: left.frames + right.frames,
          format: left.format
        )

        destination = buffer.io_buffer
        destination.copy(left.buffer.io_buffer, 0)
        destination.copy(right.buffer.io_buffer, left.buffer.size)
        buffer
      end

      def mix_sample(first, second, info)
        (first + second).clamp(info[:min], info[:max])
      end

      def build_wave_from_buffer(reference, buffer)
        reference.class.new(
          channels: buffer.channels,
          sample_rate: buffer.sample_rate,
          frames: buffer.frames,
          format: buffer.format,
          buffer: buffer
        )
      end
    end
  end
end
