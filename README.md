# SoundUtil

[![CI](https://github.com/rbutils/sound_util/actions/workflows/ci.yml/badge.svg)](https://github.com/rbutils/sound_util/actions/workflows/ci.yml)

SoundUtil is a lightweight Ruby library focused on manipulating sound data directly in memory. Its primary goal is to help scripts process and analyze audio buffers using `IO::Buffer`. The API is still evolving and should be considered unstable until version 1.0.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "sound_util"
```

And then execute:

```sh
bundle install
```

## Usage

Generate a 440 Hz stereo sine wave and stream it to stdout (pipeable into
`aplay`, `ffplay`, etc.):

```ruby
require "sound_util"

duration    = 2.0
sample_rate = 44_100
channels    = 2

wave = SoundUtil::Wave.sine(
  duration_seconds: duration,
  sample_rate: sample_rate,
  channels: channels,
  frequency: 440.0,
  amplitude: 0.6
)

wave.pipe($stdout)
```

Blocks passed to `SoundUtil::Wave.new` yield the frame index and may return a
scalar (applied to all channels) or an array of per-channel sample values.
Floats are treated as `-1.0..1.0` amplitudes and integers are clamped to the
target PCM range.

### Filters

Waves provide mutable/immutable filters similar to `image_util`:

```ruby
wave = SoundUtil::Wave.sine(duration_seconds: 1, frequency: 220)

wave = wave.gain(0.25)          # return a quieter copy
wave.fade_in!(seconds: 0.1)     # in-place fade-in over the first 0.1s
wave.fade_out!(seconds: 0.1)    # in-place fade-out over the last 0.1s
```

### CLI

The Thor CLI emits raw PCM suitable for piping into a sound device:

```sh
bundle exec exe/sound_util generate sine \
  --seconds 2 --rate 44100 --channels 2 --frequency 440 --amplitude 0.6 \
  | aplay -f S16_LE -c 2 -r 44100
```

Use `--output path.pcm` to write to a file instead of stdout.

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `rake` to run the tests and linter.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rbutils/sound_util.

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).
