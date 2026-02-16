module Chop
  module Config
    attr_accessor :atomic_diff

    def register_creation_strategy *args, &block
      Chop::Create.register_creation_strategy *args, &block
    end
  end

  extend Config
end
