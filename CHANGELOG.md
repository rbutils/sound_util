## [Unreleased]

- Add `SoundUtil::Wave` and `Wave::Buffer` with `IO::Buffer`-backed PCM storage.
- Introduce generator/filter/sink subsystems mirroring `image_util`: tone generators (`.sine`, `.silence`), gain/fade filters, playback helper (`Wave#play`), and immutable/bang variants.
- Wave constructor now defaults to mono 44.1 kHz one-second buffers; blocks accept scalar or per-channel samples.
- Add `Wave#[]`/`Wave#[]=` with float conversions and range-aware slicing/assignment.
- Add wave-combination helpers (`#+`/`#<<`, `#|`, `#&`) backed by generator-driven filters plus `Wave#channel` extraction.
- Introduce WAV codec with magic detection, multi-format PCM/float support, and `Wave.from_data`/`from_file`/`#to_string(:wav)` helpers.
- Adopt ImageUtil v0.5.0 inspectable interface for `SoundUtil::Wave` pretty-printing.
- Add `Wave#preview` sink for ImageUtil-based waveform charts.
- CLI `generate` command for sine and silence waveforms; emit raw PCM suitable for piping to sound cards.
- Set up GitHub Actions CI workflow

## [0.1.0] - 2025-09-05

- Initial release
