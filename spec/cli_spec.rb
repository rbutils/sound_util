# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe SoundUtil::CLI do
  describe "generate" do
    it "writes sine wave to output file" do
      Dir.mktmpdir do |dir|
        output = File.join(dir, "out.pcm")

        described_class.start([
                                "generate", "sine",
                                "--seconds", "0.01",
                                "--rate", "1000",
                                "--channels", "1",
                                "--frequency", "10",
                                "--amplitude", "0.5",
                                "--output", output
                              ])

        File.size(output).should be_positive
      end
    end
  end
end
