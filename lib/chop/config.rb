module Chop
  module Config
    def register_creation_strategy *args, &block
      Chop::Create.register_creation_strategy *args, &block
    end
  end
end
