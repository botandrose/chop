require "active_support/core_ext/string/inflections"
require "active_support/core_ext/object/blank"

module Chop
  class Create < Struct.new(:table, :klass, :block)
    def self.create! table, klass, &block
      new(table, klass, block).create!
    end

    attr_accessor :transformations

    def initialize(*, &other_block)
      super
      self.transformations = []
      instance_eval &block if block.respond_to?(:call)
      instance_eval &other_block if block_given?
    end

    def create! cucumber_table = table
      cucumber_table.hashes.map do |attributes|
        transformations.each { |transformation| transformation.call(attributes) }
        if klass.is_a?(Hash)
          if factory = klass[:factory_girl]
            FactoryGirl.create factory, attributes
          else
            raise "Unknown building strategy"
          end
        else
          klass.create! attributes
        end
      end
    end

    def transformation &block
      transformations << block
    end

    def rename mappings
      transformation do |attributes|
        mappings.each do |old, new|
          attributes[new.to_s] = attributes.delete(old.to_s) if attributes.key?(old.to_s)
        end
      end
    end

    def field attribute, default: ""
      if attribute.is_a?(Hash)
        rename attribute
        attribute = attribute.values.first
      end
      transformation do |attributes|
        attributes[attribute.to_s] = yield(attributes.fetch(attribute.to_s, default))
      end
    end

    def underscore_keys
      transformation do |attributes|
        new_attributes = attributes.inject({}) do |hash, (key, value)|
          hash.merge key.parameterize.underscore => value
        end
        attributes.replace new_attributes
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

