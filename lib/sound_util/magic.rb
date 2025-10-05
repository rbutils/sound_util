# frozen_string_literal: true

require "stringio"

module SoundUtil
  module Magic
    MAGIC_HEADERS = {
      wav: %w[RIFF RF64]
    }.freeze

    module_function

    def bytes_needed = 12

    def detect(data)
      return nil unless data && data.bytesize >= bytes_needed

      chunk_id = data.byteslice(0, 4)
      format = data.byteslice(8, 4)

      return :wav if MAGIC_HEADERS[:wav].include?(chunk_id) && format == "WAVE"

      nil
    end

    def detect_io(io)
      pos = io.pos
      data = io.read(bytes_needed)
      io.seek(pos)
      [detect(data), io]
    rescue Errno::ESPIPE, IOError
      data = io.read(bytes_needed)
      fmt = detect(data)
      prefix = (data || "").b
      combined = prefix + (io.read || "")
      new_io = StringIO.new(combined)
      [fmt, new_io]
    end
  end
end
