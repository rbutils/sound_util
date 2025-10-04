# frozen_string_literal: true

require "spec_helper"

RSpec.describe SoundUtil::Wave::Buffer do
  let(:buffer) { described_class.new(channels: 2, sample_rate: 48_000, frames: 2, format: :s16le) }

  it "writes and reads frames" do
    buffer.write_frame(0, [32_767, -32_768])
    buffer.write_frame(1, [0, 1])

    buffer.read_frame(0).should == [32_767, -32_768]
    buffer.read_frame(1).should == [0, 1]
  end

  it "serializes to string" do
    buffer.write_frame(0, [0, 0])
    buffer.write_frame(1, [0, 0])

    buffer.to_s.bytesize.should == buffer.size
  end

  it "wraps existing strings" do
    data = Array.new(4, 0).pack("s<*")
    buf = described_class.from_string(
      data,
      channels: 2,
      sample_rate: 48_000,
      format: :s16le
    )

    buf.frames.should == 2
    buf.size.should == data.bytesize
  end

  it "dups the underlying IO::Buffer" do
    buffer.write_frame(0, [10, 20])
    copy = buffer.dup

    buffer.write_frame(0, [30, 40])

    copy.read_frame(0).should == [10, 20]
    buffer.read_frame(0).should == [30, 40]
  end
end
