require "active_support/core_ext/string/inflections"
require "active_support/core_ext/object/blank"
require "active_support/hash_with_indifferent_access"
require "active_support/core_ext/class/attribute"

module Chop
  class Create < Struct.new(:klass, :table, :block)
    def self.create! klass, table, &block
      new(klass, table, block).create!
    end

    class_attribute :creation_strategies
    self.creation_strategies = {}

    def self.register_creation_strategy key, &block
      creation_strategies[key] = block
    end

    register_creation_strategy nil do |klass, attributes|
      klass.create! attributes
    end

    register_creation_strategy :factory_girl do |factory, attributes|
      FactoryGirl.create factory, attributes
    end

    attr_accessor :transformations, :deferred_attributes, :after_hooks

    def initialize(*, &other_block)
      super
      self.transformations = []
      self.deferred_attributes = HashWithIndifferentAccess.new
      self.after_hooks = []
      instance_eval &block if block.respond_to?(:call)
      instance_eval &other_block if block_given?
    end

    def create! cucumber_table = table
      cucumber_table.hashes.map do |attributes|
        attributes = HashWithIndifferentAccess.new(attributes)
        attributes = transformations.reduce(attributes) do |attrs, transformation|
          transformation.call(attrs)
        end

        strategy, factory = klass.is_a?(Hash) ? klass.to_a.first : [nil, klass]
        args = [factory, attributes]
        record = creation_strategies[strategy].call(*args.compact)

        after_hooks.each do |after_hook|
          after_hook.call(record, attributes.merge(deferred_attributes))
        end
        record
      end
    end

    def create &block
      self.creation_strategies = Proc.new { block }
    end

    def transformation &block
      transformations << block
    end

    def delete *keys
      transformation do |attributes|
        keys.reduce(attributes) do |attrs, key|
          attributes.delete(key)
          attributes
        end
      end
    end

    def rename mappings
      transformation do |attributes|
        mappings.reduce(attributes) do |attrs, (old, new)|
          attrs[new] = attrs.delete(old) if attrs.key?(old)
          attrs
        end
      end
    end

    def field attribute, default: ""
      if attribute.is_a?(Hash)
        rename attribute
        attribute = attribute.values.first
      end
      transformation do |attributes|
        attributes.merge attribute => yield(attributes.fetch(attribute, default))
      end
    end

    def default key, default_value = nil
      field(key, default: nil) { |value| value || default_value || yield }
    end

    def underscore_keys
      transformation do |attributes|
        attributes.reduce(HashWithIndifferentAccess.new) do |hash, (key, value)|
          hash.merge key.parameterize.underscore => value
        end
      end
    end

    def file *keys
      options = extract_options!(keys)
      path = options.fetch(:path, "features/support/fixtures")

      handle_renames! keys

      keys.each do |key|
        field key do |file|
          File.open(File.join(path, file)) if file.present?
        end
      end
    end

    def files *keys
      options = extract_options!(keys)
      path = options.fetch(:path, "features/support/fixtures")
      delimiter = options.fetch(:delimiter, " ")

      handle_renames! keys

      keys.each do |key|
        field key do |paths|
          paths.split(delimiter).map do |file|
            File.open(File.join(path, file))
          end
        end
      end
    end

    def has_many key, klass=nil, delimiter: ", ", name_field: :name
      field key do |names|
        names.split(delimiter).map do |name|
          klass.find_by!(name_field => name)
        end
      end
    end

    def has_one key, klass=nil, name_field: :name
      field key do |name|
        klass.find_by!(name_field => name) if name.present?
      end
    end
    alias_method :belongs_to, :has_one

    def after *keys, &block
      defer *keys
      after_hooks << block
    end

    def defer *keys
      transformation do |attributes|
        keys.each do |key|
          self.deferred_attributes[key] = attributes.delete(key)
        end
        attributes
      end
    end

    private

    def extract_options! keys
      if keys.last.is_a?(Hash) && keys.length > 1
        keys.pop
      else
        {}
      end
    end

    def handle_renames! keys
      if keys.first.is_a?(Hash) && keys.length == 1
        rename keys.first
        keys.replace keys.first.values
      end
    end
  end
end

