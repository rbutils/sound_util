# frozen_string_literal: true

require "image_util"

module SoundUtil
  module Sink
    module Preview
      DEFAULT_WIDTH = 600
      DEFAULT_HEIGHT = 28

      def preview(io = $stdout, width: DEFAULT_WIDTH, height: DEFAULT_HEIGHT, caption: nil)
        renderer = PreviewRenderer.new(self, width: width, height: height, caption: caption)
        rendered = renderer.render
        io.puts(rendered || "[wave preview unavailable]")
        self
      rescue LoadError
        io.puts "[wave preview unavailable]"
        self
      end

      def preview_image(width:, height:, caption: nil)
        PreviewRenderer.new(self, width: width, height: height, caption: caption).image
      end

      def pretty_print(pp)
        renderer = PreviewRenderer.new(self)
        if (rendered = renderer.render)
          pp.flush
          pp.output << rendered
          pp.text("", 0)
        else
          super
        end
      end

      class PreviewRenderer
        BACKGROUND_COLOR = [12, 12, 18, 255].freeze
        AXIS_COLOR = [60, 60, 80, 255].freeze
        CHANNEL_COLORS = [
          [90, 200, 255, 255],
          [255, 140, 220, 255],
          [180, 255, 140, 255]
        ].freeze
        TEXT_COLOR = [235, 235, 235, 255].freeze

        def initialize(wave, width: DEFAULT_WIDTH, height: DEFAULT_HEIGHT, caption: nil)
          @wave = wave
          @width = [[width, 16].max, 1000].min
          @height = [[height, 16].max, 64].min
          @caption = caption
        end

        def render
          ImageUtil::Terminal.output_image($stdin, $stdout, image)
        end

        def image
          @image ||= build_image
        end

        private

        attr_reader :wave, :width, :height, :caption

        def build_image
          img = ImageUtil::Image.new(width, height) { BACKGROUND_COLOR }
          draw_axes(img)
          draw_waveform(img)
          draw_caption(img)
          img
        end

        def draw_axes(image)
          mid = (height - 1) / 2
          width.times { |x| image[x, mid] = AXIS_COLOR }
          height.times { |y| image[0, y] = AXIS_COLOR }
        end

        def draw_waveform(image)
          return if wave.frames.zero?

          mid = (height - 1) / 2.0
          scale = (height - 1) / 2.0
          step = [wave.frames.to_f / width, 1.0].max

          width.times do |x|
            start_idx = (x * step).floor
            end_idx = [((x + 1) * step).ceil, wave.frames - 1].min
            next if start_idx.negative? || start_idx >= wave.frames

            wave.channels.times do |channel_idx|
              min_amp = 1.0
              max_amp = -1.0

              start_idx.upto(end_idx) do |frame_idx|
                sample = wave.send(:sample_to_float, wave.buffer.read_frame(frame_idx)[channel_idx])
                min_amp = sample if sample < min_amp
                max_amp = sample if sample > max_amp
              end

              top = amplitude_to_y(max_amp, mid, scale)
              bottom = amplitude_to_y(min_amp, mid, scale)
              bottom, top = top, bottom if bottom < top
              color = CHANNEL_COLORS[channel_idx % CHANNEL_COLORS.length]

              top.upto(bottom) { |y| image[x, y] = color }

              middle_sample = wave.send(:sample_to_float, wave.buffer.read_frame((start_idx + end_idx) / 2)[channel_idx])
              point_y = amplitude_to_y(middle_sample, mid, scale)
              image[x, point_y] = highlight_color(color)
            end
          end
        end

        def draw_icon(image)
          base_x = [2, width - 8].min
          base_y = 2
          ICON_COORDS.each do |dx, dy|
            x = base_x + dx
            y = base_y + dy
            next if x >= width || y >= height

            image[x, y] = ICON_COLOR
          end
        end

        def draw_caption(image)
          text = caption || Kernel.format("%dch %dHz %d frames %.2gs", wave.channels, wave.sample_rate, wave.frames, wave.duration)
          baseline = height - 8
          baseline = [baseline, 1].max
          image.bitmap_text!(text, 2, baseline, color: TEXT_COLOR)
        end

        def amplitude_to_y(amplitude, mid, scale)
          y = mid - amplitude * scale
          [[y.round, 0].max, height - 1].min
        end

        def highlight_color(color)
          dup_color = color.dup
          3.times { |idx| dup_color[idx] = [[dup_color[idx] + 40, 255].min, 0].max }
          dup_color
        end
      end
    end
  end
end
