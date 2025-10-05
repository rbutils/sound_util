# frozen_string_literal: true

# Silence a warning.
Warning[:experimental] = false

module SoundUtil
  class Wave
    class Buffer
      attr_reader :channels, :sample_rate, :frames, :format, :bytes_per_sample, :io_buffer

      def self.from_string(data, channels:, sample_rate:, format: :s16le)
        new(
          channels: channels,
          sample_rate: sample_rate,
          frames: calculate_frames(data.bytesize, channels: channels, format: format),
          format: format,
          io_buffer: IO::Buffer.for(data)
        )
      end

      def self.calculate_frames(bytes, channels:, format: :s16le)
        format_info = Wave::SUPPORTED_FORMATS.fetch(format.to_sym) do
          raise ArgumentError, "unsupported format: #{format}"
        end

        frame_stride = channels * format_info[:bytes_per_sample]
        raise ArgumentError, "buffer size not aligned to frame size" unless (bytes % frame_stride).zero?

        bytes / frame_stride
      end

      def initialize(channels:, sample_rate:, frames:, format:, io_buffer: nil)
        @format = format.to_sym
        format_info = Wave::SUPPORTED_FORMATS.fetch(@format) do
          raise ArgumentError, "unsupported format: #{format}"
        end

        @channels = Integer(channels)
        raise ArgumentError, "channels must be positive" unless @channels.positive?

        @sample_rate = Integer(sample_rate)
        raise ArgumentError, "sample_rate must be positive" unless @sample_rate.positive?

        @frames = Integer(frames)
        raise ArgumentError, "frames must be non-negative" if @frames.negative?

        @bytes_per_sample = format_info[:bytes_per_sample]
        @frame_stride = @bytes_per_sample * @channels
        @pack_code = format_info[:pack_code]
        @pack_template = @pack_code ? (@pack_code * @channels) : nil

        total_bytes = @frames * @frame_stride
        @io_buffer = io_buffer || IO::Buffer.new(total_bytes)

        return if @io_buffer.size == total_bytes

        raise ArgumentError, "buffer size mismatch (expected #{total_bytes}, got #{@io_buffer.size})"
      end

      def initialize_copy(other)
        super
        @io_buffer = IO::Buffer.new(other.size)
        @io_buffer.copy(other.io_buffer)
      end

      def write_frame(frame_idx, samples)
        validate_frame_index(frame_idx)
        offset = frame_idx * @frame_stride
        data = if @pack_template
                 samples.pack(@pack_template)
               else
                 encode_samples(samples)
               end
        @io_buffer.copy(IO::Buffer.for(data), offset)
      end

      def read_frame(frame_idx)
        validate_frame_index(frame_idx)
        data = @io_buffer.get_string(frame_idx * @frame_stride, @frame_stride)
        if @pack_template
          data.unpack(@pack_template)
        else
          decode_samples(data)
        end
      end

      def to_s
        @io_buffer.get_string
      end

      def size
        @io_buffer.size
      end

      private

      def validate_frame_index(frame_idx)
        raise IndexError, "frame index out of bounds" unless frame_idx.between?(0, frames - 1)
      end

      def encode_samples(samples)
        case @format
        when :s24le
          bytes = samples.flat_map do |sample|
            value = sample.to_i
            value += 0x1_000000 if value.negative?
            value &= 0xFFFFFF

            [value & 0xFF, (value >> 8) & 0xFF, (value >> 16) & 0xFF]
          end
          bytes.pack("C*")
        else
          raise ArgumentError, "unsupported format for encoding: #{@format.inspect}"
        end
      end

      def decode_samples(data)
        case @format
        when :s24le
          bytes = data.bytes
          samples = []
          bytes.each_slice(3) do |slice|
            next unless slice.length == 3

            b0, b1, b2 = slice
            value = b0 | (b1 << 8) | (b2 << 16)
            value -= 0x1_000000 if (b2 & 0x80).positive?
            samples << value
          end
          samples
        else
          raise ArgumentError, "unsupported format for decoding: #{@format.inspect}"
        end
      end
    end
  end
end
