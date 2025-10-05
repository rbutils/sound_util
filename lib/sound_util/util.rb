# frozen_string_literal: true

module SoundUtil
  module Util
    module_function

    def assert_same_class!(reference, other)
      return if other.is_a?(reference.class)

      raise ArgumentError, "expected wave of type #{reference.class}, got #{other.class}"
    end

    def assert_same_format!(left, right)
      return if left.sample_rate == right.sample_rate && left.format == right.format

      raise ArgumentError, "wave format or sample rate mismatch"
    end

    def assert_channel_count!(wave, expected_channels)
      return if wave.channels == expected_channels

      raise ArgumentError, "wave channel count mismatch"
    end

    def assert_frame_count!(wave, expected_frames)
      return if wave.frames == expected_frames

      raise ArgumentError, "wave frame count mismatch"
    end

    def zero_frame(channels)
      Array.new(channels, 0)
    end

    def fill_channels(value, channels)
      if value.is_a?(Array)
        raise ArgumentError, "channel count mismatch" unless value.length == channels

        value.dup
      else
        Array.new(channels, value)
      end
    end

    def fill_frames(value, frames, channels)
      Array.new(frames) { fill_channels(value, channels) }
    end

    def ensure_same_kind!(left, right)
      assert_same_class!(left, right)
      assert_same_format!(left, right)
    end

    def assert_dimensions!(wave, frames: nil, channels: nil)
      assert_frame_count!(wave, frames) if frames
      assert_channel_count!(wave, channels) if channels
    end

    def build_buffer(reference, channels:, frames:, format: reference.format, sample_rate: reference.sample_rate)
      reference.class::Buffer.new(
        channels: channels,
        sample_rate: sample_rate,
        frames: frames,
        format: format
      )
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

    def extract_channel_samples(frame, count)
      count.times.map { |idx| frame[idx] }
    end

    def extract_selected_channels(frame, indices)
      indices.map { |idx| frame[idx] }
    end
  end
end
