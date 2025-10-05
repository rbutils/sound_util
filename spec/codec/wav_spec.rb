# frozen_string_literal: true

require "spec_helper"
RSpec.describe SoundUtil::Codec::Wav do
  def build_wav(data_bytes, channels:, sample_rate:, bits_per_sample:, audio_format: described_class::PCM)
    block_align = (channels * bits_per_sample) / 8
    byte_rate = sample_rate * block_align

    fmt_chunk = String.new("fmt ", encoding: Encoding::ASCII_8BIT)
    fmt_chunk << [16].pack("V")
    fmt_chunk << [
      audio_format,
      channels,
      sample_rate,
      byte_rate,
      block_align,
      bits_per_sample
    ].pack("v2V2v2")

    data_chunk = String.new("data", encoding: Encoding::ASCII_8BIT)
    data_chunk << [data_bytes.bytesize].pack("V")
    data_chunk << data_bytes
    riff_size = 4 + fmt_chunk.bytesize + data_chunk.bytesize

    header = String.new("RIFF", encoding: Encoding::ASCII_8BIT)
    header << [riff_size].pack("V")
    header << "WAVE"
    header << fmt_chunk
    header << data_chunk
    header
  end

  def pack_s24le(values)
    bytes = values.flat_map do |value|
      val = value
      val += 0x1_000000 if val.negative?
      val &= 0xFFFFFF
      [val & 0xFF, (val >> 8) & 0xFF, (val >> 16) & 0xFF]
    end
    bytes.pack("C*")
  end

  describe ".decode" do
    it "parses 16-bit PCM data" do
      samples = [0, 1, -1]
      data = samples.pack("s<*")
      wav = build_wav(data, channels: 1, sample_rate: 44_100, bits_per_sample: 16)

      wave = described_class.decode(:wav, wav)

      wave.format.should == :s16le
      wave.sample_rate.should == 44_100
      wave.channels.should == 1
      wave.frames.should == 3
      wave[1].should be_within(1e-4).of(1.0 / 32_767)
    end

    it "parses 24-bit PCM data" do
      samples = [500_000, -500_000]
      data = pack_s24le(samples)
      wav = build_wav(data, channels: 1, sample_rate: 48_000, bits_per_sample: 24)

      wave = described_class.decode(:wav, wav)

      wave.format.should == :s24le
      wave.frames.should == 2
      wave.buffer.read_frame(0).first.should == 500_000
      wave.buffer.read_frame(1).first.should == -500_000
    end

    it "parses 32-bit float data" do
      samples = [0.0, 0.5, -0.5, 0.75]
      data = samples.pack("e*")
      wav = build_wav(data, channels: 2, sample_rate: 12_000, bits_per_sample: 32, audio_format: described_class::IEEE_FLOAT)

      wave = described_class.decode(:wav, wav)

      wave.format.should == :f32le
      wave.channels.should == 2
      wave.frames.should == 2
      wave[0, 0].should be_within(1e-6).of(0.0)
      wave[1, 0].should be_within(1e-6).of(-0.5)
      wave[1, 1].should be_within(1e-6).of(0.75)
    end
  end

  describe ".encode" do
    it "produces a RIFF/WAVE file" do
      wave = SoundUtil::Wave.new(channels: 1, sample_rate: 8_000, frames: 2, format: :s16le) do |idx|
        idx.zero? ? 0.25 : -0.25
      end

      data = described_class.encode(:wav, wave)

      data.start_with?("RIFF").should be(true)
      data.byteslice(8, 4).should == "WAVE"

      decoded = described_class.decode(:wav, data)
      decoded.frames.should == 2
      decoded.format.should == :s16le
      decoded[0].should be_within(1e-4).of(0.25)
    end

    it "converts to target sample format" do
      wave = SoundUtil::Wave.new(channels: 1, sample_rate: 44_100, frames: 1, format: :f32le) { 0.5 }

      data = described_class.encode(:wav, wave, sample_format: :s24le)
      decoded = described_class.decode(:wav, data)

      decoded.format.should == :s24le
      decoded[0].should be_within(1e-4).of(0.5)
    end
  end
  
  describe ".encode_io" do
    it "writes into an IO object" do
      wave = SoundUtil::Wave.new(frames: 1) { 0.1 }
      io = StringIO.new

      described_class.encode_io(:wav, wave, io)
      io.string.start_with?("RIFF").should be(true)
    end
  end
end
