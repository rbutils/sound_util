# frozen_string_literal: true

require_relative "filter"
require_relative "generator"
require_relative "sink"

module SoundUtil
  class Wave
    autoload :Buffer, "sound_util/wave/buffer"

    extend SoundUtil::Generator::Tone
    include SoundUtil::Filter::Gain
    include SoundUtil::Filter::Fade
    include SoundUtil::Sink::Playback

    SUPPORTED_FORMATS = {
      s16le: {
        bytes_per_sample: 2,
        min: -32_768,
        max: 32_767,
        pack_code: "s<",
        float_scale: 32_767
      }
    }.freeze

    attr_reader :channels, :sample_rate, :frames, :format, :buffer

    def initialize(channels: 1, sample_rate: 44_100, frames: nil, format: :s16le, buffer: nil, &block)
      @format = format.to_sym
      info = SUPPORTED_FORMATS[@format]
      raise ArgumentError, "unsupported format: #{format}" unless info

      @channels = Integer(channels)
      raise ArgumentError, "channels must be positive" unless @channels.positive?

      @sample_rate = Integer(sample_rate)
      raise ArgumentError, "sample_rate must be positive" unless @sample_rate.positive?

      frames ||= @sample_rate
      @frames = Integer(frames)
      raise ArgumentError, "frames must be non-negative" if @frames.negative?

      @buffer = buffer || Buffer.new(
        channels: @channels,
        sample_rate: @sample_rate,
        frames: @frames,
        format: @format
      )

      fill_from_block(&block) if block_given?
    end

    def self.from_string(data, channels:, sample_rate:, format: :s16le)
      buffer = Buffer.from_string(
        data,
        channels: channels,
        sample_rate: sample_rate,
        format: format
      )
      new(
        channels: channels,
        sample_rate: sample_rate,
        frames: buffer.frames,
        format: format,
        buffer: buffer
      )
    end

    def each_frame
      return enum_for(:each_frame) { frames } unless block_given?

      frames.times do |idx|
        yield buffer.read_frame(idx)
      end
    end

    def pipe(io = $stdout)
      io.binmode if io.respond_to?(:binmode)
      io.write(to_string)
    end

    def to_string
      buffer.to_s
    end

    def format_info
      SUPPORTED_FORMATS[format]
    end

    def duration
      frames.to_f / sample_rate
    end

    def initialize_from_buffer(other_buffer)
      @buffer = other_buffer
    end

    def initialize_copy(other)
      super
      @buffer = other.buffer.dup
    end

    private

    def fill_from_block
      frames.times do |frame_idx|
        sample = yield(frame_idx)
        values = normalize_sample(sample)
        buffer.write_frame(frame_idx, values)
      end
    end

    def normalize_sample(sample)
      case sample
      when Array
        raise ArgumentError, "expected #{channels} channels, got #{sample.length}" unless sample.length == channels

        sample.map { |value| encode_value(value) }
      else
        encoded = encode_value(sample)
        Array.new(channels, encoded)
      end
    end

    def encode_value(value)
      info = format_info

      case value
      when Float
        clamp = value.clamp(-1.0, 1.0)
        if clamp >= 1.0
          info[:max]
        elsif clamp <= -1.0
          info[:min]
        else
          (clamp * info[:float_scale]).round.clamp(info[:min], info[:max])
        end
      when Integer
        value.clamp(info[:min], info[:max])
      when nil
        0
      else
        raise ArgumentError, "unsupported sample value: #{value.inspect}"
      end
    end

    def mutate_frames!
      frames.times do |frame_idx|
        samples = buffer.read_frame(frame_idx)
        new_samples = yield(frame_idx, samples)
        buffer.write_frame(frame_idx, new_samples)
      end
      self
    end
  end
end
