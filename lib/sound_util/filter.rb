# frozen_string_literal: true

module SoundUtil
  module Filter
    autoload :Mixin, "sound_util/filter/_mixin"
    autoload :Gain, "sound_util/filter/gain"
    autoload :Fade, "sound_util/filter/fade"
    autoload :Combine, "sound_util/filter/combine"
    autoload :Resample, "sound_util/filter/resample"
  end
end
