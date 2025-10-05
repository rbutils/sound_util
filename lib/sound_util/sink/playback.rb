# frozen_string_literal: true

module SoundUtil
  module Sink
    module Playback
      FORMAT_FLAGS = {
        u8: "U8",
        s16le: "S16_LE",
        s24le: "S24_LE",
        s32le: "S32_LE",
        f32le: "FLOAT_LE",
        f64le: "FLOAT64_LE"
      }.freeze

      DEFAULT_COMMAND = lambda do |wave|
        flag = FORMAT_FLAGS[wave.format]
        raise SoundUtil::Error, "unsupported playback format: #{wave.format}" unless flag

        [
          "aplay",
          "-t", "raw",
          "-f", flag,
          "-c", wave.channels.to_s,
          "-r", wave.sample_rate.to_s,
          "-"
        ]
      end

      def play(command: nil, io: nil)
        if io
          pipe(io)
          return self
        end

        cmd = build_command(command)
        IO.popen(cmd, "wb") do |handle|
          pipe(handle)
          handle.close_write
          Process.wait(handle.pid) if handle.respond_to?(:pid)
        end
        self
      rescue Errno::ENOENT
        cmd_display = cmd.is_a?(Array) ? cmd.join(" ") : cmd.to_s
        raise SoundUtil::Error, "playback command not found: #{cmd_display}"
      end

      private

      def build_command(command)
        return command unless command.nil?

        DEFAULT_COMMAND.call(self)
      end
    end
  end
end
