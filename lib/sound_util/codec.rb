# frozen_string_literal: true

module SoundUtil
  module Codec
    class UnsupportedFormatError < SoundUtil::Error; end

    @encoders = []
    @decoders = []

    class << self
      attr_reader :encoders, :decoders

      def register_encoder(codec_const, *formats)
        encoders << { codec: codec_const, formats: formats.map { |f| f.to_s.downcase } }
      end

      def register_decoder(codec_const, *formats)
        decoders << { codec: codec_const, formats: formats.map { |f| f.to_s.downcase } }
      end

      def register_codec(codec_const, *formats)
        register_encoder(codec_const, *formats)
        register_decoder(codec_const, *formats)
      end

      def supported?(format)
        fmt = format.to_s.downcase
        encoders.any? { |entry| entry[:formats].include?(fmt) && codec_supported?(entry[:codec], fmt) } ||
          decoders.any? { |entry| entry[:formats].include?(fmt) && codec_supported?(entry[:codec], fmt) }
      end

      def encode(format, wave, codec: nil, **kwargs)
        codec = find_codec(encoders, format, codec)
        codec.encode(format, wave, **kwargs)
      end

      def decode(format, data, codec: nil, **kwargs)
        codec = find_codec(decoders, format, codec)
        codec.decode(format, data, **kwargs)
      end

      def encode_io(format, wave, io, codec: nil, **kwargs)
        codec = find_codec(encoders, format, codec)
        if codec.respond_to?(:encode_io)
          codec.encode_io(format, wave, io, **kwargs)
        else
          io << codec.encode(format, wave, **kwargs)
        end
      end

      def decode_io(format, io, codec: nil, **kwargs)
        codec = find_codec(decoders, format, codec)
        if codec.respond_to?(:decode_io)
          codec.decode_io(format, io, **kwargs)
        else
          codec.decode(format, io.read, **kwargs)
        end
      end

      def detect(data)
        Magic.detect(data)
      end

      def detect_io(io)
        Magic.detect_io(io).first
      end

      private

      def find_codec(list, format, preferred = nil)
        fmt = format.to_s.downcase
        if preferred
          record = list.find { |entry| entry[:formats].include?(fmt) && entry[:codec].to_s == preferred.to_s }
          raise UnsupportedFormatError, "unsupported format #{format}" unless record

          codec = const_get(record[:codec])
          if codec.respond_to?(:supported?) && !codec.supported?(fmt.to_sym)
            raise UnsupportedFormatError, "unsupported format #{format}"
          end

          return codec
        end

        list.each do |entry|
          next unless entry[:formats].include?(fmt)

          codec = const_get(entry[:codec])
          next if codec.respond_to?(:supported?) && !codec.supported?(fmt.to_sym)

          return codec
        end

        raise UnsupportedFormatError, "unsupported format #{format}"
      end

      def codec_supported?(codec_const, fmt)
        codec = const_get(codec_const)
        !codec.respond_to?(:supported?) || codec.supported?(fmt.to_sym)
      end
    end

    autoload :Wav, "sound_util/codec/wav"

    register_codec :Wav, :wav
  end
end
