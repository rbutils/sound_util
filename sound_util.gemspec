# frozen_string_literal: true

require_relative "lib/sound_util/version"

Gem::Specification.new do |spec|
  spec.name = "sound_util"
  spec.version = SoundUtil::VERSION
  spec.authors = ["hmdne"]
  spec.email = ["54514036+hmdne@users.noreply.github.com"]

  spec.summary = "Simple sound buffer helpers"
  spec.description = "Lightweight audio buffer utilities for manipulating sound in memory using IO::Buffer."
  spec.homepage = "https://github.com/rbutils/sound_util"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['source_code_uri'] = 'https://github.com/rbutils/sound_util'
  spec.metadata['changelog_uri'] = 'https://github.com/rbutils/sound_util/blob/master/CHANGELOG.md'
  spec.metadata['documentation_uri'] = 'https://github.com/rbutils/sound_util#readme'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/rbutils/sound_util/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "image_util", ">= 0.5.0"
  spec.add_dependency "io-console", "~> 0.5"
  spec.add_dependency "thor", "~> 1.2"
end
