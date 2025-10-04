# frozen_string_literal: true

require "spec_helper"
require "stringio"

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
end
