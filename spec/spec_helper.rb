# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  enable_coverage :branch
  minimum_coverage 80
end

require "sound_util"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"

  config.expect_with :rspec do |c|
    c.syntax = :should
  end

  config.mock_with :rspec do |c|
    c.syntax = %i[should expect]
  end
end
