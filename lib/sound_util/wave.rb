# frozen_string_literal: true

require "image_util"
require_relative "filter"
require_relative "generator"
require_relative "sink"

module SoundUtil
  class Wave
    autoload :Buffer, "sound_util/wave/buffer"

    extend SoundUtil::Generator::Tone
    extend SoundUtil::Generator::Combine
    include ImageUtil::Inspectable
    include SoundUtil::Filter::Gain
    include SoundUtil::Filter::Fade
    include SoundUtil::Filter::Combine
    include SoundUtil::Filter::Resample
    include SoundUtil::Sink::Playback
    include SoundUtil::Sink::Preview

    SUPPORTED_FORMATS = {
      u8: {
        bytes_per_sample: 1,
        min: 0,
        max: 255,
        pack_code: "C",
        float_scale: 127.5,
        zero_offset: 128,
        type: :unsigned
      },
      s16le: {
        bytes_per_sample: 2,
        min: -32_768,
        max: 32_767,
        pack_code: "s<",
        float_scale: 32_767,
        type: :signed
      },
      s24le: {
        bytes_per_sample: 3,
        min: -8_388_608,
        max: 8_388_607,
        float_scale: 8_388_607,
        type: :signed
      },
      s32le: {
        bytes_per_sample: 4,
        min: -2_147_483_648,
        max: 2_147_483_647,
        pack_code: "l<",
        float_scale: 2_147_483_647,
        type: :signed
      },
      f32le: {
        bytes_per_sample: 4,
        pack_code: "e",
        type: :float
      },
      f64le: {
        bytes_per_sample: 8,
        pack_code: "g",
        type: :float
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

    def self.from_data(data, format = nil, codec: nil, **kwargs)
      fmt = format || SoundUtil::Codec.detect(data)
      raise ArgumentError, "could not detect format" unless fmt

      SoundUtil::Codec.decode(fmt, data, codec: codec, **kwargs)
    end

    def self.from_file(path_or_io, format = nil, codec: nil, **kwargs)
      if format
        if path_or_io.respond_to?(:read)
          path_or_io.binmode if path_or_io.respond_to?(:binmode)
          SoundUtil::Codec.decode_io(format, path_or_io, codec: codec, **kwargs)
        else
          File.open(path_or_io, "rb") do |io|
            SoundUtil::Codec.decode_io(format, io, codec: codec, **kwargs)
          end
        end
      elsif path_or_io.respond_to?(:read)
        path_or_io.binmode if path_or_io.respond_to?(:binmode)
        fmt, io = SoundUtil::Magic.detect_io(path_or_io)
        raise ArgumentError, "could not detect format" unless fmt

        SoundUtil::Codec.decode_io(fmt, io, codec: codec, **kwargs)
      else
        File.open(path_or_io, "rb") do |io|
          fmt, detected_io = SoundUtil::Magic.detect_io(io)
          raise ArgumentError, "could not detect format" unless fmt

          SoundUtil::Codec.decode_io(fmt, detected_io, codec: codec, **kwargs)
        end
      end
    end

    def each_frame
      return enum_for(:each_frame) { frames } unless block_given?

      frames.times do |idx|
        yield buffer.read_frame(idx)
      end
    end

    def [](*args)
      frame_spec, channel_spec = args
      frame_indices = frame_indices_for(frame_spec)
      channel_indices = channel_indices_for(channel_spec)

      if frame_indices.length == 1 && channel_indices.length == 1
        frame = buffer.read_frame(frame_indices.first)
        sample_to_float(frame[channel_indices.first])
      elsif frame_indices.length == 1
        frame = buffer.read_frame(frame_indices.first)
        channel_indices.map { |idx| sample_to_float(frame[idx]) }
      else
        build_subwave(frame_indices, channel_indices)
      end
    end

    def channel(index)
      indices = channel_indices_for(index)
      raise ArgumentError, "channel index must reference a single channel" unless indices.length == 1

      build_subwave(frame_indices_for(nil), indices)
    end

    def []=(*args, value)
      frame_spec, channel_spec = args
      frame_indices = frame_indices_for(frame_spec)
      channel_indices = channel_indices_for(channel_spec)

      encoded_frames = encoded_values_for_assignment(value, frame_indices.length, channel_indices.length)

      frame_indices.each_with_index do |frame_idx, frame_pos|
        samples = buffer.read_frame(frame_idx)
        channel_indices.each_with_index do |channel_idx, ch_pos|
          samples[channel_idx] = encoded_frames[frame_pos][ch_pos]
        end
        buffer.write_frame(frame_idx, samples)
      end
    end

    def pipe(io = $stdout)
      io.binmode if io.respond_to?(:binmode)
      io.write(to_string)
    end

    def to_string(format = nil, codec: nil, **kwargs)
      case format&.to_sym
      when nil, :pcm
        buffer.to_s
      else
        SoundUtil::Codec.encode(format, self, codec: codec, **kwargs)
      end
    end

    def to_file(path_or_io, format = :wav, codec: nil, **kwargs)
      raise ArgumentError, "format required" unless format

      if path_or_io.respond_to?(:write)
        path_or_io.binmode if path_or_io.respond_to?(:binmode)
        SoundUtil::Codec.encode_io(format, self, path_or_io, codec: codec, **kwargs)
      else
        File.open(path_or_io, "wb") do |io|
          SoundUtil::Codec.encode_io(format, self, io, codec: codec, **kwargs)
        end
      end
      self
    end

    def inspect_image
      preview_image
    end

    def format_info
      SUPPORTED_FORMATS[format]
    end

    def duration
      frames.to_f / sample_rate
    end

    def initialize_from_buffer(other_buffer)
      @buffer = other_buffer
      @channels = other_buffer.channels
      @sample_rate = other_buffer.sample_rate
      @frames = other_buffer.frames
      @format = other_buffer.format
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
        Util.fill_channels(encoded, channels)
      end
    end

    def encode_value(value)
      info = format_info

      case info[:type]
      when :signed
        encode_signed_value(info, value)
      when :unsigned
        encode_unsigned_value(info, value)
      when :float
        encode_float_value(value)
      else
        raise ArgumentError, "unsupported format type: #{info[:type].inspect}"
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

    def frame_indices_for(spec)
      indices_for(spec, frames)
    end

    def channel_indices_for(spec)
      indices_for(spec, channels)
    end

    def indices_for(spec, size)
      case spec
      when nil
        (0...size).to_a
      when Integer
        [normalize_index(spec, size)]
      when Range
        range_to_indices(spec, size)
      else
        raise ArgumentError, "unsupported index specification: #{spec.inspect}"
      end
    end

    def normalize_index(idx, size)
      idx += size if idx.negative?
      raise IndexError, "index #{idx} out of bounds" unless idx.between?(0, size - 1)

      idx
    end

    def range_to_indices(range, size)
      start = range.begin.nil? ? 0 : normalize_index(range.begin, size)
      finish = range.end.nil? ? size - 1 : normalize_index(range.end, size)
      finish -= 1 if range.exclude_end?
      raise IndexError, "empty range" if finish < start

      (start..finish).to_a
    end

    def build_subwave(frame_indices, channel_indices)
      new_buffer = Util.build_buffer(self, channels: channel_indices.length, frames: frame_indices.length)

      frame_indices.each_with_index do |frame_idx, new_frame_idx|
        source = buffer.read_frame(frame_idx)
        selected = Util.extract_selected_channels(source, channel_indices)
        new_buffer.write_frame(new_frame_idx, selected)
      end

      Util.build_wave_from_buffer(self, new_buffer)
    end

    def sample_to_float(sample)
      info = format_info

      case info[:type]
      when :signed
        (sample.to_f / info[:float_scale]).clamp(-1.0, 1.0)
      when :unsigned
        offset = info[:zero_offset]
        scale = info[:float_scale]
        ((sample - offset).to_f / scale).clamp(-1.0, 1.0)
      when :float
        sample.to_f.clamp(-1.0, 1.0)
      else
        raise ArgumentError, "unsupported format type: #{info[:type].inspect}"
      end
    end

    def encoded_values_for_assignment(value, frame_count, channel_count)
      case value
      when Wave
        Util.ensure_same_kind!(self, value)
        Util.assert_dimensions!(value, frames: frame_count, channels: channel_count)

        Array.new(frame_count) do |frame_idx|
          frame = value.buffer.read_frame(frame_idx)
          Util.extract_channel_samples(frame, channel_count)
        end
      when Numeric
        encoded = encode_value(value)
        Util.fill_frames(encoded, frame_count, channel_count)
      when Array
        encode_array_assignment(value, frame_count, channel_count)
      else
        raise ArgumentError, "unsupported assignment value: #{value.inspect}"
      end
    end

    def encode_array_assignment(value, frame_count, channel_count)
      if frame_count == 1
        [encode_channel_values(value, channel_count)]
      elsif value.length == frame_count
        value.map { |entry| encode_channel_values(entry, channel_count) }
      else
        encoded = encode_channel_values(value, channel_count)
        Util.fill_frames(encoded, frame_count, channel_count)
      end
    end

    def encode_channel_values(entry, channel_count)
      if channel_count == 1
        Util.fill_channels(encode_value(entry), 1)
      else
        case entry
        when Numeric
          encoded = encode_value(entry)
          Util.fill_channels(encoded, channel_count)
        when Array
          raise ArgumentError, "channel count mismatch" unless entry.length == channel_count

          entry.map { |val| encode_value(val) }
        when NilClass
          encoded = encode_value(0)
          Util.fill_channels(encoded, channel_count)
        else
          raise ArgumentError, "unsupported channel assignment value: #{entry.inspect}"
        end
      end
    end

    def encode_signed_value(info, value)
      case value
      when Float
        clamp = value.clamp(-1.0, 1.0)
        return info[:max] if clamp >= 1.0
        return info[:min] if clamp <= -1.0

        (clamp * info[:float_scale]).round.clamp(info[:min], info[:max])
      when Integer
        value.clamp(info[:min], info[:max])
      when NilClass
        0
      else
        raise ArgumentError, "unsupported sample value: #{value.inspect}"
      end
    end

    def encode_unsigned_value(info, value)
      zero = info[:zero_offset]
      scale = info[:float_scale]

      case value
      when Float
        clamp = value.clamp(-1.0, 1.0)
        return info[:max] if clamp >= 1.0
        return info[:min] if clamp <= -1.0

        ((clamp * scale) + zero).round.clamp(info[:min], info[:max])
      when Integer
        value.clamp(info[:min], info[:max])
      when NilClass
        zero
      else
        raise ArgumentError, "unsupported sample value: #{value.inspect}"
      end
    end

    def encode_float_value(value)
      case value
      when Float
        value.clamp(-1.0, 1.0)
      when Integer
        value.to_f.clamp(-1.0, 1.0)
      when NilClass
        0.0
      else
        raise ArgumentError, "unsupported sample value: #{value.inspect}"
      end
    end
  end
end
