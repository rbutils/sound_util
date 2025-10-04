# frozen_string_literal: true

require "thor"

module SoundUtil
  class CLI < Thor
    desc "version", "Display SoundUtil version"
    def version
      puts SoundUtil::VERSION
    end

    desc "generate TYPE", "Generate PCM audio and write to stdout or file"
    option :seconds, type: :numeric, default: 1.0, aliases: "-s", banner: "SECONDS"
    option :rate, type: :numeric, default: 44_100, aliases: "-r", banner: "HZ"
    option :channels, type: :numeric, default: 2, aliases: "-c", banner: "N"
    option :frequency, type: :numeric, default: 440.0, aliases: "-f", banner: "HZ"
    option :amplitude, type: :numeric, default: 1.0, aliases: "-a"
    option :format, type: :string, default: "s16le"
    option :output, type: :string, aliases: "-o"
    def generate(type)
      wave = case type
             when "sine"
               SoundUtil::Wave.sine(
                 duration_seconds: options[:seconds],
                 sample_rate: options[:rate],
                 channels: options[:channels],
                 frequency: options[:frequency],
                 amplitude: options[:amplitude],
                 format: options[:format]
               )
             when "silence"
               SoundUtil::Wave.silence(
                 duration_seconds: options[:seconds],
                 sample_rate: options[:rate],
                 channels: options[:channels],
                 format: options[:format]
               )
             else
               raise ArgumentError, "unsupported generator: #{type}"
             end

      write_wave(wave)
    end

    no_commands do
      def write_wave(wave)
        if options[:output]
          File.open(options[:output], "wb") { |io| wave.pipe(io) }
        else
          wave.pipe($stdout)
        end
      end
    end
  end
end
