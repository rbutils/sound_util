# frozen_string_literal: true

module SoundUtil
  module Sink
    module Playback
      DEFAULT_COMMAND = lambda do |wave|
        [
          "aplay",
          "-t", "raw",
          "-f", "S16_LE",
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
