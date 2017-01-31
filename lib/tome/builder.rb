module Tome
  class Builder < Struct.new(:table, :klass, :block)
    def self.build! table, klass, &block
      new(table, klass, block).build!
    end

    attr_accessor :transformations

    def initialize(*)
      super
      self.transformations = []
      underscore_keys
      instance_eval &block if block.respond_to?(:call)
    end

    def build!
      table.hashes.map do |attributes|
        transformations.each { |transformation| transformation.call(attributes) }
        klass.create! attributes
      end
    end

    def transformation &block
      transformations << block
    end

    def underscore_keys
      transformation do |attributes|
        new_attributes = attributes.inject({}) do |hash, (key, value)|
          hash.merge key.parameterize.underscore => value
        end
        attributes.replace new_attributes
      end
    end

    def has_attached_file *keys
      keys.each do |key|
        key = key.to_s
        transformation do |attributes|
          if attributes[key].present?
            attributes[key] = File.open(Rails.root.join("features/support/fixtures/#{attributes[key]}"))
          end
        end
      end
    end
  end
end

