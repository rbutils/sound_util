# frozen_string_literal: true

require "spec_helper"
require "stringio"
require "image_util/terminal"

RSpec.describe SoundUtil::Wave do
  describe ".new" do
    it "defaults to mono 44.1 kHz one-second buffer" do
      wave = described_class.new

      wave.channels.should == 1
      wave.sample_rate.should == 44_100
      wave.frames.should == 44_100
    end

    it "fills all channels when block returns a scalar" do
      wave = described_class.new(channels: 2, sample_rate: 48_000, frames: 3) do |frame|
        frame.zero? ? 0.5 : -0.25
      end

      wave.buffer.read_frame(0).should == [16_384, 16_384]
      wave.buffer.read_frame(1).should == [-8_192, -8_192]
    end

    it "respects per-channel arrays from the block" do
      wave = described_class.new(channels: 2, sample_rate: 48_000, frames: 1) do |_frame|
        [1.0, -1.0]
      end

      wave.buffer.read_frame(0).should == [32_767, -32_768]
    end
  end

  describe ".sine" do
    it "builds a sine waveform with the requested frequency" do
      wave = described_class.sine(
        duration_seconds: 1.0,
        sample_rate: 4,
        channels: 1,
        frequency: 1.0,
        amplitude: 1.0
      )

      samples = (0...4).map { |frame| wave.buffer.read_frame(frame).first }
      samples.should == [0, 32_767, 0, -32_768]
    end
  end

  describe "filters" do
    let(:wave) do
      described_class.new(channels: 1, sample_rate: 4, frames: 4) { 0.5 }
    end

    it "applies gain immutably" do
      louder = wave.gain(2.0)

      wave.buffer.read_frame(0).first.should == 16_384
      louder.buffer.read_frame(0).first.should == 32_767
    end

    it "applies gain in place" do
      wave.gain!(0.5)
      wave.buffer.read_frame(0).first.should == 8_192
    end

    it "fades in over the requested duration" do
      wave.fade_in!(seconds: 1.0)

      first, second, third, fourth = (0...4).map { |frame| wave.buffer.read_frame(frame).first }
      first.should == 4_096
      second.should == 8_192
      third.should == 12_288
      fourth.should == 16_384
    end

    it "fades out over the requested duration" do
      wave = described_class.new(channels: 1, sample_rate: 4, frames: 4) { 1.0 }
      wave.fade_out!(seconds: 0.5)

      samples = (0...4).map { |frame| wave.buffer.read_frame(frame).first }
      samples.should == [32_767, 32_767, 16_384, 0]
    end
  end

  describe "combining waves" do
    it "concatenates waves with +" do
      left = described_class.new(channels: 1, sample_rate: 4, frames: 2) { |frame| frame.zero? ? 0.5 : -0.5 }
      right = described_class.new(channels: 1, sample_rate: 4, frames: 1) { 0.25 }

      combined = left + right

      combined.frames.should == 3
      combined.channels.should == 1
      combined[0].should be_within(1e-4).of(0.5)
      combined[1].should be_within(1e-4).of(-0.5)
      combined[2].should be_within(1e-4).of(0.25)

      left.frames.should == 2
    end

    it "appends waves in place with <<" do
      wave = described_class.new(channels: 1, sample_rate: 4, frames: 1) { -0.25 }
      other = described_class.new(channels: 1, sample_rate: 4, frames: 2) { |frame| frame.zero? ? 0.75 : 0.5 }

      (wave << other).should equal(wave)
      wave.frames.should == 3
      wave[0].should be_within(1e-4).of(-0.25)
      wave[1].should be_within(1e-4).of(0.75)
      wave[2].should be_within(1e-4).of(0.5)
    end

    it "mixes waves with |" do
      first = described_class.new(channels: 1, sample_rate: 8, frames: 3) { |frame| frame.zero? ? 0.6 : 0.4 }
      second = described_class.new(channels: 1, sample_rate: 8, frames: 2) { 0.7 }

      mixed = first | second

      mixed.frames.should == 3
      mixed[0].should be_within(1e-4).of(1.0)
      mixed[1].should be_within(1e-4).of(1.0)
      mixed[2].should be_within(1e-4).of(0.4)
    end

    it "stacks channels with &" do
      mono = described_class.new(channels: 1, sample_rate: 2, frames: 2) { |frame| frame.zero? ? 0.5 : -0.5 }
      extra = described_class.new(channels: 1, sample_rate: 2, frames: 3) { 0.25 }

      stacked = mono & extra

      stacked.channels.should == 2
      stacked.frames.should == 3
      stacked[0][0].should be_within(1e-4).of(0.5)
      stacked[0][1].should be_within(1e-4).of(0.25)
      stacked[1][0].should be_within(1e-4).of(-0.5)
      stacked[1][1].should be_within(1e-4).of(0.25)
      stacked[2][0].should be_within(1e-4).of(0.0)
      stacked[2][1].should be_within(1e-4).of(0.25)
    end

    it "raises when formats differ" do
      left = described_class.new(channels: 1, sample_rate: 4, frames: 1)
      right = described_class.new(channels: 1, sample_rate: 8, frames: 1)

      -> { left + right }.should raise_error(ArgumentError)
      -> { left | right }.should raise_error(ArgumentError)
      -> { left & right }.should raise_error(ArgumentError)
    end
  end

  describe "#pipe" do
    it "writes raw PCM bytes to the given IO" do
      wave = described_class.silence(
        duration_seconds: 0.001,
        sample_rate: 1_000,
        channels: 2
      )

      io = StringIO.new
      wave.pipe(io)

      io.string.bytesize.should == wave.buffer.size
    end
  end

  describe "#dup" do
    it "deep copies the buffer" do
      wave = described_class.new(frames: 2) { 1.0 }
      copy = wave.dup

      wave.gain!(0.5)

      copy.buffer.read_frame(0).first.should == 32_767
      wave.buffer.read_frame(0).first.should == 16_384
    end
  end

  describe "indexing" do
    let(:wave) do
      SoundUtil::Wave.new(channels: 2, sample_rate: 8, frames: 4) do |frame|
        [frame / 4.0, -frame / 4.0]
      end
    end

    it "returns floats for single frame" do
      wave[0].should == [0.0, 0.0]
      wave[1, 0].should be_within(1e-4).of(0.25)
    end

    it "returns a sub-wave for frame ranges" do
      sub = wave[1..2]
      sub.should be_a(SoundUtil::Wave)
      sub.frames.should == 2
      sub.channels.should == 2
      sub[0].first.should be_within(1e-4).of(0.25)
    end

    it "supports channel ranges" do
      sub = wave[0..2, 0]
      sub.channels.should == 1
      sub[1].should be_within(1e-4).of(0.25)
    end

    it "assigns numeric values" do
      wave[0] = 0.5
      wave[0][0].should be_within(1e-4).of(0.5)
      wave[0][1].should be_within(1e-4).of(0.5)

      wave[1, 1] = -0.25
      wave[1, 1].should be_within(1e-4).of(-0.25)
    end

    it "assigns arrays across frames" do
      wave[0..1] = [[0.1, -0.1], [0.2, -0.2]]

      wave[0][0].should be_within(1e-4).of(0.1)
      wave[0][1].should be_within(1e-4).of(-0.1)
      wave[1][0].should be_within(1e-4).of(0.2)
      wave[1][1].should be_within(1e-4).of(-0.2)
    end

    it "assigns using another wave" do
      other = SoundUtil::Wave.new(channels: 2, sample_rate: 8, frames: 2) do |frame|
        [frame * 0.1, frame * 0.2]
      end

      wave[1..2] = other

      wave[1].each { |sample| sample.should be_within(1e-4).of(0.0) }
      wave[2][0].should be_within(1e-4).of(0.1)
      wave[2][1].should be_within(1e-4).of(0.2)
    end
  end

  describe "#channel" do
    it "returns a single-channel wave" do
      wave = described_class.new(channels: 2, sample_rate: 4, frames: 2) do |frame|
        [frame.zero? ? 0.5 : 0.25, frame.zero? ? -0.5 : -0.25]
      end

      channel = wave.channel(1)

      channel.should be_a(described_class)
      channel.channels.should == 1
      channel.frames.should == 2
      channel[0].should be_within(1e-4).of(-0.5)
      channel[1].should be_within(1e-4).of(-0.25)
    end

    it "accepts negative indices" do
      wave = described_class.new(channels: 3, sample_rate: 4, frames: 1) do
        [0.1, 0.2, 0.3]
      end

      channel = wave.channel(-1)

      channel[0].should be_within(1e-4).of(0.3)
    end

    it "raises when multiple channels requested" do
      wave = described_class.new(channels: 2, sample_rate: 4, frames: 1) { [0.0, 0.0] }

      -> { wave.channel(0..1) }.should raise_error(ArgumentError)
    end
  end

  describe "#play" do
    let(:wave) { described_class.new(frames: 4) { 0.1 } }

    it "pipes audio into a playback command" do
      fake_io = StringIO.new
      fake_io.define_singleton_method(:pid) { 1234 }
      fake_io.define_singleton_method(:close_write) { close }

      Process.should_receive(:wait).with(1234)
      IO.should_receive(:popen).with(array_including("aplay", "-"), "wb").and_yield(fake_io)

      wave.play

      fake_io.string.bytesize.should == wave.buffer.size
    end

    it "raises SoundUtil::Error when command missing" do
      IO.should_receive(:popen).and_raise(Errno::ENOENT)

      -> { wave.play(command: ["missing-cmd"]) }.should raise_error(SoundUtil::Error)
    end

    it "accepts a custom IO" do
      fake_io = StringIO.new

      wave.play(io: fake_io)

      fake_io.string.bytesize.should == wave.buffer.size
    end
  end

  describe "#preview" do
    let(:wave) { described_class.sine(duration_seconds: 0.1, sample_rate: 800, channels: 2, frequency: 220) }

    it "renders preview" do
      io = StringIO.new
      ImageUtil::Terminal.should_receive(:output_image).and_return("--preview--")

      wave.preview(io)

      io.string.should include("--preview--")
    end

    it "falls back to text when rendering fails" do
      io = StringIO.new
      ImageUtil::Terminal.should_receive(:output_image).and_return(nil)

      wave.preview(io)

      io.string.should include("[wave preview unavailable]")
    end
  end

  describe "#pretty_print" do
    let(:wave) { described_class.new(frames: 4) { 0.1 } }

    it "renders preview via pretty printer" do
      output = StringIO.new
      pp = double("pp", output: output, flush: nil)
      pp.should_receive(:text).with("", 0)
      ImageUtil::Terminal.should_receive(:output_image).and_return("--preview--")

      wave.pretty_print(pp)

      output.string.should include("--preview--")
    end
  end
end
