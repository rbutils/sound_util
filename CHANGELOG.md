## [Unreleased]

- Add `SoundUtil::Wave` and `Wave::Buffer` with `IO::Buffer`-backed PCM storage.
- Introduce generator/filter/sink subsystems mirroring `image_util`: tone generators (`.sine`, `.silence`), gain/fade filters, playback helper (`Wave#play`), and immutable/bang variants.
- Wave constructor now defaults to mono 44.1 kHz one-second buffers; blocks accept scalar or per-channel samples.
- Add `Wave#[]`/`Wave#[]=` with float conversions and range-aware slicing/assignment.
- CLI `generate` command for sine and silence waveforms; emit raw PCM suitable for piping to sound cards.
- Set up GitHub Actions CI workflow

## [0.1.0] - 2025-09-05

- Initial release
