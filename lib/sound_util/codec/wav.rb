# frozen_string_literal: true

require "stringio"

module SoundUtil
  module Codec
    # rubocop:disable Metrics/ModuleLength
    module Wav
      PCM = 0x0001
      IEEE_FLOAT = 0x0003
      EXTENSIBLE = 0xFFFE

      SUBFORMAT_PCM = [1, 0, 0, 0, 0, 0, 16, 0, 128, 0, 0, 170, 0, 56, 155, 113].pack("C*").freeze
      SUBFORMAT_IEEE_FLOAT = [3, 0, 0, 0, 0, 0, 16, 0, 128, 0, 0, 170, 0, 56, 155, 113].pack("C*").freeze

      CHUNK_ALIGN = 2

      SUPPORTED_FORMATS = {
        u8: { bits_per_sample: 8, audio_format: PCM },
        s16le: { bits_per_sample: 16, audio_format: PCM },
        s24le: { bits_per_sample: 24, audio_format: PCM },
        s32le: { bits_per_sample: 32, audio_format: PCM },
        f32le: { bits_per_sample: 32, audio_format: IEEE_FLOAT },
        f64le: { bits_per_sample: 64, audio_format: IEEE_FLOAT }
      }.freeze

      module_function

      def supported?(format)
        format == :wav
      end

      def decode(_format, data, **_kwargs)
        io = StringIO.new(data)
        decode_io(:wav, io)
      end

      def decode_io(_format, io, **_kwargs)
        io.binmode if io.respond_to?(:binmode)

        riff, _total_size, wave_id = read_riff_header(io)
        raise UnsupportedFormatError, "unsupported RIFF type: #{riff}" unless riff == "RIFF"
        raise UnsupportedFormatError, "not a WAVE file" unless wave_id == "WAVE"

        fmt_chunk = nil
        data_chunk = nil

        until io.eof?
          id = io.read(4)
          break unless id

          size = read_uint32(io)
          payload = io.read(size)
          raise UnsupportedFormatError, "unexpected EOF" if payload.nil? || payload.bytesize < size

          io.read(1) if (size % CHUNK_ALIGN).positive?

          case id
          when "fmt "
            fmt_chunk = payload
          when "data"
            data_chunk = payload
            break if fmt_chunk
          else
            next
          end
        end

        raise UnsupportedFormatError, "missing fmt chunk" unless fmt_chunk
        raise UnsupportedFormatError, "missing data chunk" unless data_chunk

        fmt = parse_fmt_chunk(fmt_chunk)
        ensure_supported_format!(fmt)

        validate_data_size!(data_chunk.bytesize, fmt)

        SoundUtil::Wave.from_string(
          data_chunk,
          channels: fmt[:channels],
          sample_rate: fmt[:sample_rate],
          format: fmt[:internal_format]
        )
      end

      def encode(_format, wave, sample_format: nil, bits_per_sample: nil)
        io = StringIO.new
        encode_io(:wav, wave, io, sample_format: sample_format, bits_per_sample: bits_per_sample)
        io.string
      end

      def encode_io(_format, wave, io, sample_format: nil, bits_per_sample: nil)
        io.binmode if io.respond_to?(:binmode)

        format_symbol = determine_target_format(wave, sample_format, bits_per_sample)
        spec = SUPPORTED_FORMATS.fetch(format_symbol)
        bytes_per_sample = SoundUtil::Wave::SUPPORTED_FORMATS.fetch(format_symbol)[:bytes_per_sample]
        block_align = bytes_per_sample * wave.channels
        byte_rate = wave.sample_rate * block_align
        bits = spec[:bits_per_sample]

        data = export_wave_data(wave, format_symbol)
        data_size = data.bytesize
        data_padding = (data_size % CHUNK_ALIGN).positive? ? "\x00" : ""
        data_chunk = String.new("data", encoding: Encoding::ASCII_8BIT)
        data_chunk << [data_size].pack("V")
        data_chunk << data
        data_chunk << data_padding

        fmt_body = [
          spec[:audio_format],
          wave.channels,
          wave.sample_rate,
          byte_rate,
          block_align,
          bits
        ].pack("v2V2v2")

        fmt_chunk = build_chunk("fmt ", fmt_body)
        fact_chunk = spec[:audio_format] == PCM ? nil : build_chunk("fact", [wave.frames].pack("V"))

        total_size = 4 + fmt_chunk.bytesize + (fact_chunk ? fact_chunk.bytesize : 0) + data_chunk.bytesize

        io << "RIFF"
        io << [total_size].pack("V")
        io << "WAVE"
        io << fmt_chunk
        io << fact_chunk if fact_chunk
        io << data_chunk
        io
      end

      def build_chunk(id, payload)
        size = payload.bytesize
        id + [size].pack("V") + payload
      end
      private_class_method :build_chunk

      def read_riff_header(io)
        chunk_id = io.read(4)
        size = read_uint32(io)
        format = io.read(4)
        [chunk_id, size, format]
      end

      def read_uint16(io)
        data = io.read(2)
        raise UnsupportedFormatError, "unexpected EOF" unless data && data.bytesize == 2

        data.unpack1("v")
      end

      def read_uint32(io)
        data = io.read(4)
        raise UnsupportedFormatError, "unexpected EOF" unless data && data.bytesize == 4

        data.unpack1("V")
      end

      def parse_fmt_chunk(data)
        io = StringIO.new(data)

        audio_format = read_uint16(io)
        channels = read_uint16(io)
        sample_rate = read_uint32(io)
        byte_rate = read_uint32(io)
        block_align = read_uint16(io)
        bits_per_sample = read_uint16(io)

        resolved_format = audio_format
        valid_bits = bits_per_sample

        if audio_format == EXTENSIBLE
          cb_size = read_uint16(io)
          raise UnsupportedFormatError, "invalid extensible header" if cb_size.nil? || cb_size < 22

          valid_bits = read_uint16(io)
          valid_bits = bits_per_sample if valid_bits.zero?
          _channel_mask = read_uint32(io)
          subformat = read_guid(io)
          resolved_format = resolve_subformat(subformat)
          skip = cb_size - 22
          io.read(skip) if skip.positive?
        end

        {
          audio_format: resolved_format,
          channels: channels,
          sample_rate: sample_rate,
          byte_rate: byte_rate,
          block_align: block_align,
          bits_per_sample: valid_bits
        }
      end

      def read_guid(io)
        data = io.read(16)
        raise UnsupportedFormatError, "unexpected EOF" unless data && data.bytesize == 16

        data
      end

      def resolve_subformat(subformat)
        case subformat
        when SUBFORMAT_PCM
          PCM
        when SUBFORMAT_IEEE_FLOAT
          IEEE_FLOAT
        else
          raise UnsupportedFormatError, "unsupported extensible subformat"
        end
      end

      def ensure_supported_format!(fmt)
        fmt[:internal_format] = case fmt[:audio_format]
                                when PCM
                                  map_pcm_bits(fmt[:bits_per_sample])
                                when IEEE_FLOAT
                                  map_float_bits(fmt[:bits_per_sample])
                                else
                                  raise UnsupportedFormatError, "unsupported audio format #{fmt[:audio_format]}"
                                end
      end

      def map_pcm_bits(bits)
        case bits
        when 8 then :u8
        when 16 then :s16le
        when 24 then :s24le
        when 32 then :s32le
        else
          raise UnsupportedFormatError, "unsupported PCM bit depth #{bits}"
        end
      end

      def map_float_bits(bits)
        case bits
        when 32 then :f32le
        when 64 then :f64le
        else
          raise UnsupportedFormatError, "unsupported float bit depth #{bits}"
        end
      end

      def validate_data_size!(bytesize, fmt)
        expected_stride = fmt[:block_align]
        raise UnsupportedFormatError, "corrupt data chunk" unless (bytesize % expected_stride).zero?
      end

      def determine_target_format(wave, sample_format, bits)
        return sample_format.to_sym if sample_format

        if bits
          return map_pcm_bits(bits) if [8, 16, 24, 32].include?(bits) && !%i[f32le f64le].include?(wave.format)
          return map_float_bits(bits) if [32, 64].include?(bits) && %i[f32le f64le].include?(wave.format)
        end

        wave.format.tap do |fmt|
          raise UnsupportedFormatError, "unsupported wave format #{fmt}" unless SUPPORTED_FORMATS.key?(fmt)
        end
      end

      def export_wave_data(wave, target_format)
        return wave.buffer.to_s if wave.format == target_format

        converted = SoundUtil::Wave.new(
          channels: wave.channels,
          sample_rate: wave.sample_rate,
          frames: wave.frames,
          format: target_format
        ) do |frame_idx|
          wave[frame_idx]
        end

        converted.to_string
      end
    end
    # rubocop:enable Metrics/ModuleLength
  end
end
