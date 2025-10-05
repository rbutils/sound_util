# frozen_string_literal: true

require "spec_helper"

RSpec.describe SoundUtil::Magic do
  let(:wav_header) do
    header = String.new("RIFF", encoding: Encoding::ASCII_8BIT)
    header << [12].pack("V")
    header << "WAVE"
    header << ("\x00" * 12)
    header
  end

  it "detects WAV signatures" do
    described_class.detect(wav_header).should == :wav
  end

  it "returns nil for unknown data" do
    described_class.detect("NOPE").should be_nil
  end

  it "detects IO streams" do
    io = StringIO.new(wav_header)
    fmt, reused = described_class.detect_io(io)
    fmt.should == :wav
    reused.read(4).should == "RIFF"
  end
end
