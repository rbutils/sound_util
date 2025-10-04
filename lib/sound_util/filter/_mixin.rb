# frozen_string_literal: true

module SoundUtil
  module Filter
    module Mixin
      def define_immutable_version(*names)
        names.each do |name|
          define_method(name) do |*args, **kwargs, &block|
            dup.tap { |wave| wave.public_send("#{name}!", *args, **kwargs, &block) }
          end
        end
      end

      def define_mutable_version(*names)
        names.each do |name|
          define_method("#{name}!") do |*args, **kwargs, &block|
            initialize_from_buffer(public_send(name, *args, **kwargs, &block).buffer)
            self
          end
        end
      end

      module_function :define_immutable_version, :define_mutable_version
    end
  end
end
